"""Cells of the lesion-outline (segmentation) notebook, assembled by build_notebooks.py.

A separate model from the classifier: a U-Net that draws the lesion's outline, trained with the classifier's exact split.
"""
from pathlib import Path

BREAST_SEGMENT = [
    ("markdown", r"""
# Femora — Breast Lesion Outline (U-Net)

The classifier says *what* a scan most likely shows; its heatmap shows roughly *where it looked*. This notebook trains a
second, separate model that draws the **outline of the lesion itself**, so the app can show its shape and an approximate size.

**Data**: every scan with a radiologist's lesion mask from BUSI, BrEaST-Lesions-USG and BUS-BRA, plus BUSI's normal scans
(empty masks, so the model learns to draw nothing when there is no lesion).

**Split**: exactly the deployed classifier's train / validation / test assignment (`ml/busbra_split.csv`). The test scans
were never seen by either model, so the outline is judged on the same images as the classifier.

**Model**: U-Net with an ImageNet-pretrained ResNet34 encoder, 256 × 256 grayscale input padded (not stretched) to a square,
the same preprocessing as the classifier. Loss: binary cross-entropy + Dice. The epoch with the best validation Dice is kept.

**Reported on the test set** (with the exported ONNX model, which is what the backend runs): Dice and IoU per hospital, the
share of lesions outlined reasonably well (Dice ≥ 0.5), and how often an outline is wrongly drawn on a normal scan.
"""),
    ("code", r"""
%pip install -q segmentation-models-pytorch onnx onnxruntime onnxscript
"""),
    ("code", r"""
import copy, glob, io, json, os, random, shutil, urllib.request, zipfile, warnings
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
from PIL import Image, ImageOps
import torch, torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from torchvision.transforms import v2
from torchvision import tv_tensors
import segmentation_models_pytorch as smp
warnings.filterwarnings("ignore")

INPUT, WORK, TMP = "/kaggle/input", "/kaggle/working", "/tmp/femora"
OUT = f"{WORK}/model"
for d in (OUT, TMP):
    os.makedirs(d, exist_ok=True)
SEED, IMG, BATCH, EPOCHS = 42, 256, 16, 45
MEAN = np.array([0.485, 0.456, 0.406], np.float32)[:, None, None]
STD = np.array([0.229, 0.224, 0.225], np.float32)[:, None, None]
random.seed(SEED); np.random.seed(SEED); torch.manual_seed(SEED); torch.cuda.manual_seed_all(SEED)
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(DEVICE, torch.__version__, smp.__version__)

# ---- Preprocessing shared with backend/app.py (keep the two in sync)
def pad_square(img, fill=0):
    w, h = img.size
    s = max(w, h)
    canvas = Image.new(img.mode, (s, s), fill)
    canvas.paste(img, ((s - w) // 2, (s - h) // 2))
    return canvas

def to_gray(img):
    return pad_square(ImageOps.exif_transpose(img).convert("L")).resize((IMG, IMG), Image.BILINEAR)

def to_mask(paths, size):
    # several masks per scan (BUSI) are merged; padded like the scan, nearest-neighbour so it stays binary
    m = np.zeros(size[::-1], bool)
    for p in paths:
        m |= np.asarray(Image.open(p).convert("L").resize(size, Image.NEAREST)) > 127
    return np.asarray(pad_square(Image.fromarray(m.astype(np.uint8) * 255)).resize((IMG, IMG), Image.NEAREST)) > 127

def normalize(gray):
    x = np.asarray(gray, np.float32) / 255.0
    return ((np.repeat(x[None], 3, 0) - MEAN) / STD).astype(np.float32)

def download(url, dest):
    if not os.path.exists(dest):
        request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(request) as r, open(dest, "wb") as f:
            shutil.copyfileobj(r, f)
    return dest
"""),
    ("code", "SPLIT_CSV = '''" + (Path(__file__).parent / "busbra_split.csv").read_text(encoding="utf-8") + "'''"),
    ("markdown", "## 1. Load the scans and masks, with the classifier's split"),
    ("code", r"""
rows = []
busi_root = glob.glob(f"{INPUT}/**/Dataset_BUSI_with_GT", recursive=True)[0]
for label in ["normal", "benign", "malignant"]:
    for path in sorted(glob.glob(f"{busi_root}/{label}/*.png")):
        if "_mask" not in os.path.basename(path):
            rows.append({"path": path, "source": "BUSI", "label": label,
                         "masks": sorted(glob.glob(glob.escape(path[:-4]) + "_mask*.png"))})

TCIA = "https://www.cancerimagingarchive.net/wp-content/uploads/"
zip_path = download(TCIA + "BrEaST-Lesions_USG-images_and_masks-Dec-15-2023.zip", f"{TMP}/breast_usg.zip")
xlsx_path = download(TCIA + "BrEaST-Lesions-USG-clinical-data-Dec-15-2023.xlsx", f"{TMP}/breast_usg.xlsx")
if not glob.glob(f"{TMP}/breast_usg/**/case001.png", recursive=True):
    zipfile.ZipFile(zip_path).extractall(f"{TMP}/breast_usg")
img_dir = os.path.dirname(glob.glob(f"{TMP}/breast_usg/**/case001.png", recursive=True)[0])
for r in pd.read_excel(xlsx_path).itertuples():
    masks = [f"{img_dir}/{m}" for m in r.Mask_tumor_filename.split("&")] if isinstance(r.Mask_tumor_filename, str) else []
    rows.append({"path": f"{img_dir}/{r.Image_filename}", "source": "BrEaST", "label": r.Classification, "masks": masks})

bra_dir = os.path.dirname(glob.glob(f"{INPUT}/**/bus_data.csv", recursive=True)[0])
for r in pd.read_csv(f"{bra_dir}/bus_data.csv").itertuples():
    mask = f"{bra_dir}/Masks/mask_{r.ID[4:]}.png"
    rows.append({"path": f"{bra_dir}/Images/{r.ID}.png", "source": "BUS-BRA", "label": r.Pathology,
                 "masks": [mask] if os.path.exists(mask) else []})

df = pd.DataFrame(rows)
split = pd.read_csv(io.StringIO(SPLIT_CSV))
split = dict(zip(split["source"] + "/" + split["file"], split["split"]))
df["split"] = (df["source"] + "/" + df["path"].map(os.path.basename)).map(split)
df = df[df["split"].notna()]                                   # the classifier dropped these (near-duplicates)
# a lesion scan without a mask can't be used; normal scans get an empty mask
df = df[(df["label"] == "normal") | (df["masks"].map(len) > 0)].reset_index(drop=True)
print(pd.crosstab([df["source"], df["label"]], df["split"], margins=True))

grays, masks = [], []
for r in df.itertuples():
    img = Image.open(r.path)
    grays.append(np.asarray(to_gray(img)))
    masks.append(to_mask(r.masks, img.size) if r.masks else np.zeros((IMG, IMG), bool))
grays, masks = np.stack(grays), np.stack(masks)
idx = {s: np.where(df["split"] == s)[0] for s in ["train", "val", "test"]}
print("median share of the image covered by a lesion:", np.median(masks[(df["label"] != "normal").values].mean((1, 2))).round(3))

fig, axes = plt.subplots(3, 4, figsize=(13, 10))
for ax, i in zip(axes.flat, df[df["label"] != "normal"].groupby("source").head(4).index):
    ax.imshow(grays[i], cmap="gray"); ax.contour(masks[i], colors="lime", linewidths=1)
    ax.set_title(f"{df.source[i]} · {df.label[i]}", fontsize=9); ax.axis("off")
plt.tight_layout(); plt.show()
"""),
    ("markdown", "## 2. Training"),
    ("code", r"""
AUG = v2.Compose([
    v2.RandomHorizontalFlip(),   # no vertical flip: the transducer is always at the top of the image
    v2.RandomApply([v2.RandomAffine(degrees=10, translate=(0.08, 0.08), scale=(0.8, 1.2))], p=0.7),
    v2.RandomApply([v2.ColorJitter(brightness=0.35, contrast=0.35)], p=0.7),
    v2.RandomApply([v2.GaussianBlur(5, sigma=(0.1, 1.5))], p=0.25),
])

class SegDS(Dataset):
    def __init__(self, ids, augment=False):
        self.ids, self.augment = np.asarray(ids), augment
    def __len__(self):
        return len(self.ids)
    def __getitem__(self, i):
        j = self.ids[i]
        g, m = grays[j], masks[j]
        if self.augment:
            gi, mi = AUG(tv_tensors.Image(torch.from_numpy(g.copy())[None]),
                         tv_tensors.Mask(torch.from_numpy(m.astype(np.uint8))[None]))
            g, m = gi[0].numpy(), mi[0].numpy() > 0
        return torch.from_numpy(normalize(g)), torch.from_numpy(m[None].astype(np.float32)), int(j)

def loader(ids, augment=False):
    return DataLoader(SegDS(ids, augment), batch_size=BATCH, shuffle=augment, drop_last=augment, num_workers=4,
                      pin_memory=True)

net = smp.Unet("resnet34", encoder_weights="imagenet", in_channels=3, classes=1).to(DEVICE)
dice_loss = smp.losses.DiceLoss("binary", from_logits=True)
bce = nn.BCEWithLogitsLoss()
opt = torch.optim.AdamW(net.parameters(), lr=3e-4, weight_decay=1e-4)
sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=3e-4, total_steps=EPOCHS * (len(idx["train"]) // BATCH), pct_start=0.1)
scaler = torch.cuda.amp.GradScaler()

@torch.no_grad()
def predict(model, ids):
    model.eval()
    out = []
    for x, *_ in loader(ids):
        with torch.autocast("cuda", enabled=DEVICE.type == "cuda"):
            out.append(torch.sigmoid(model(x.to(DEVICE)).float()).cpu().numpy()[:, 0])
    return np.concatenate(out)

def dice(pred, true):
    # an empty outline on an empty mask counts as perfect
    inter, total = (pred & true).sum(), pred.sum() + true.sum()
    return 1.0 if total == 0 else 2 * inter / total

def iou(pred, true):
    union = (pred | true).sum()
    return 1.0 if union == 0 else (pred & true).sum() / union

lesion_val = [k for k, j in enumerate(idx["val"]) if masks[j].any()]
best, history = (-1, None, -1), []
for epoch in range(EPOCHS):
    net.train()
    losses = []
    for x, y, _ in loader(idx["train"], augment=True):
        x, y = x.to(DEVICE), y.to(DEVICE)
        with torch.autocast("cuda", enabled=DEVICE.type == "cuda"):
            logits = net(x)
            loss = bce(logits.float(), y) + dice_loss(logits.float(), y)
        opt.zero_grad(set_to_none=True)
        scaler.scale(loss).backward(); scaler.step(opt); scaler.update(); sched.step()
        losses.append(loss.item())
    pv = predict(net, idx["val"]) > 0.5
    val_dice = float(np.mean([dice(pv[k], masks[idx["val"][k]]) for k in lesion_val]))
    history.append((epoch, float(np.mean(losses)), val_dice))
    print(f"epoch {epoch:2d}  loss {np.mean(losses):.4f}  val Dice (lesions) {val_dice:.4f}")
    if val_dice > best[0]:
        best = (val_dice, copy.deepcopy(net.state_dict()), epoch)
net.load_state_dict(best[1])
print(f"best epoch {best[2]}, val Dice {best[0]:.4f}")

h = np.array(history)
plt.figure(figsize=(7, 3.5)); plt.plot(h[:, 0], h[:, 1], label="train loss"); plt.plot(h[:, 0], h[:, 2], label="val Dice")
plt.axvline(best[2], ls="--", c="grey"); plt.legend(); plt.xlabel("epoch"); plt.tight_layout()
plt.savefig(f"{OUT}/seg_training.png", dpi=130); plt.show()
"""),
    ("markdown", r"""
## 3. Export to ONNX (fp16 weight storage) and check parity

The backend runs this ONNX file. As with the classifier, conv weights are *stored* in fp16 and cast back to fp32 when the
model loads, halving the file size; all computation stays fp32.
"""),
    ("code", r"""
import onnx, onnxruntime as ort
from onnx import helper, numpy_helper, TensorProto

net = net.float().cpu().eval()
fp32_path = f"{TMP}/breast_seg_fp32.onnx"
dummy = torch.from_numpy(normalize(grays[0]))[None]
export_args = dict(input_names=["image"], output_names=["mask_logits"], opset_version=17,
                   dynamic_axes={"image": {0: "batch"}, "mask_logits": {0: "batch"}})
try:
    torch.onnx.export(net, dummy, fp32_path, dynamo=False, **export_args)
except TypeError:
    torch.onnx.export(net, dummy, fp32_path, **export_args)

model = onnx.load(fp32_path)
graph = model.graph
initializers, casts = [], []
for init in graph.initializer:
    w = numpy_helper.to_array(init)
    if w.dtype == np.float32 and w.ndim >= 2:
        initializers.append(numpy_helper.from_array(w.astype(np.float16), init.name + "_fp16"))
        casts.append(helper.make_node("Cast", [init.name + "_fp16"], [init.name], to=TensorProto.FLOAT))
    else:
        initializers.append(numpy_helper.from_array(w, init.name))
nodes = casts + [copy.deepcopy(n) for n in graph.node]
graph.ClearField("initializer"); graph.initializer.extend(initializers)
graph.ClearField("node"); graph.node.extend(nodes)
onnx.checker.check_model(model)
ONNX_PATH = f"{OUT}/breast_seg_unet.onnx"
onnx.save(model, ONNX_PATH)
print(f"fp32 {os.path.getsize(fp32_path) / 1e6:.1f} MB -> deployed {os.path.getsize(ONNX_PATH) / 1e6:.1f} MB")

session = ort.InferenceSession(ONNX_PATH, providers=["CPUExecutionProvider"])
def onnx_prob(ids, batch=16):
    out = [session.run(None, {"image": np.stack([normalize(grays[j]) for j in ids[i:i + batch]])})[0][:, 0]
           for i in range(0, len(ids), batch)]
    return 1 / (1 + np.exp(-np.concatenate(out)))

with torch.no_grad():
    torch_prob = torch.sigmoid(net(torch.from_numpy(np.stack([normalize(grays[j]) for j in idx["test"][:32]])))).numpy()[:, 0]
parity = float(np.abs(onnx_prob(idx["test"][:32]) - torch_prob).max())
print("max |P_onnx - P_torch| on 32 test scans:", round(parity, 5))
assert parity < 0.05
"""),
    ("markdown", r"""
## 4. Post-processing and the test set

The backend keeps pixels with probability ≥ 0.5, then only the **largest connected region** (one lesion per result), and
drops outlines smaller than a minimum area. The minimum area is chosen on the **validation** split and then applied unchanged
to the test split.
"""),
    ("code", r"""
def largest_component(m):
    # 4-connected labelling without scipy, mirroring backend/app.py
    lab = np.zeros(m.shape, np.int32)
    best_label, best_n, cur = 0, 0, 0
    for y0, x0 in zip(*np.nonzero(m)):
        if lab[y0, x0]:
            continue
        cur += 1
        stack, n = [(y0, x0)], 0
        lab[y0, x0] = cur
        while stack:
            y, x = stack.pop(); n += 1
            for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= yy < m.shape[0] and 0 <= xx < m.shape[1] and m[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = cur; stack.append((yy, xx))
        if n > best_n:
            best_label, best_n = cur, n
    return lab == best_label if best_label else np.zeros_like(m)

def postprocess(prob, min_area):
    m = largest_component(prob >= 0.5)
    return m if m.mean() >= min_area else np.zeros_like(m)

def evaluate(ids, prob, min_area):
    out = []
    for j, p in zip(ids, prob):
        pred, true = postprocess(p, min_area), masks[j]
        out.append({"source": df.source[j], "label": df.label[j], "dice": dice(pred, true), "iou": iou(pred, true),
                    "outlined": bool(pred.any())})
    return pd.DataFrame(out)

prob_val, prob_test = onnx_prob(idx["val"]), onnx_prob(idx["test"])
choices = []
for min_area in [0.0, 0.002, 0.005, 0.01]:
    ev = evaluate(idx["val"], prob_val, min_area)
    les, nor = ev[ev.label != "normal"], ev[ev.label == "normal"]
    choices.append((min_area, les.dice.mean(), 1 - nor.outlined.mean()))
    print(f"min area {min_area:.3f}: val lesion Dice {les.dice.mean():.4f}, normal scans left blank {1 - nor.outlined.mean():.2%}")
top = max(c[1] for c in choices)
MIN_AREA = max(c[0] for c in choices if c[1] >= top - 0.005)   # the largest minimum area that costs < 0.005 Dice
print("chosen minimum area:", MIN_AREA)

ev = evaluate(idx["test"], prob_test, MIN_AREA)
les, nor = ev[ev.label != "normal"], ev[ev.label == "normal"]
def summary(e):
    return {"scans": int(len(e)), "dice_mean": round(float(e.dice.mean()), 4), "dice_median": round(float(e.dice.median()), 4),
            "iou_mean": round(float(e.iou.mean()), 4), "share_dice_at_least_0_5": round(float((e.dice >= 0.5).mean()), 4),
            "share_missed": round(float((~e.outlined).mean()), 4)}
test_metrics = summary(les)
per_source = {s: summary(g) for s, g in les.groupby("source")}
per_label = {s: summary(g) for s, g in les.groupby("label")}
normal_blank = {"scans": int(len(nor)), "share_left_blank": round(float(1 - nor.outlined.mean()), 4)}
print(json.dumps({"test_lesions": test_metrics, "per_source": per_source, "per_label": per_label,
                  "normal_scans": normal_blank}, indent=2))

# qualitative examples: best, typical and worst test outlines
order = les.sort_values("dice").index.tolist()
mid = len(order) // 2
pick = order[-4:] + order[mid - 2: mid + 2] + order[:4]
fig, axes = plt.subplots(3, 4, figsize=(13, 10))
for ax, k in zip(axes.flat, pick):
    j = idx["test"][k]
    ax.imshow(grays[j], cmap="gray")
    ax.contour(masks[j], colors="lime", linewidths=1.2)
    pred = postprocess(prob_test[k], MIN_AREA)
    if pred.any():
        ax.contour(pred, colors="magenta", linewidths=1.2)
    ax.set_title(f"{df.source[j]} · {df.label[j]} · Dice {ev.dice[k]:.2f}", fontsize=9); ax.axis("off")
plt.suptitle("Test scans: radiologist (green) vs model (magenta); rows = best, typical, worst")
plt.tight_layout(); plt.savefig(f"{OUT}/seg_examples.png", dpi=130); plt.show()
"""),
    ("code", r"""
meta = {
    "onnx_file": "breast_seg_unet.onnx",
    "architecture": "U-Net, ResNet34 encoder (ImageNet), segmentation_models_pytorch " + smp.__version__,
    "input": {"size": IMG, "mean": MEAN.ravel().tolist(), "std": STD.ravel().tolist(), "channels": "grayscale x3",
              "preprocessing": "grayscale, padded to a square, bilinear resize"},
    "probability_threshold": 0.5,
    "min_area_fraction": MIN_AREA,
    "best_epoch": int(best[2]), "epochs": EPOCHS, "val_dice": round(float(best[0]), 4),
    "split": "same as the deployed classifier (ml/busbra_split.csv)",
    "train_scans": int(len(idx["train"])), "val_scans": int(len(idx["val"])), "test_scans": int(len(idx["test"])),
    "test_metrics": test_metrics, "per_source_test": per_source, "per_label_test": per_label,
    "normal_test_scans": normal_blank,
    "onnx_parity": round(parity, 5),
    "datasets": ["BUSI (Al-Dhabyani et al., 2020)", "BrEaST-Lesions-USG (Pawłowska et al., 2024, TCIA, CC BY 4.0)",
                 "BUS-BRA (Gómez-Flores et al., Medical Physics 2024)"],
}
with open(f"{OUT}/breast_seg_meta.json", "w") as f:
    json.dump(meta, f, indent=2)
print(os.listdir(OUT))
"""),
]
