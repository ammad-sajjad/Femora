"""Lesion outline: a U-Net (ml/segment_cells.py) draws the edge of the lesion on the scan, with its shape and relative size.

The outline model is optional: without models/breast_seg_meta.json the scan result simply has no outline. Sizes are given
relative to the scan's height, because an uploaded image carries no centimetre scale; the app turns them into centimetres
when the user reads the depth off the scan's ruler.
"""
import base64
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image
from pydantic import BaseModel

MODELS = Path(__file__).parent / "models"
DRAW_SIZE = 512
OUTLINE_RGB = np.array([255, 64, 180], np.float32)   # magenta: stands out on grey ultrasound
FILL_ALPHA, EDGE_WIDTH = 0.22, 3


class LesionOutline(BaseModel):
    image_jpeg: str  # base64 JPEG: the scan with the lesion's outline drawn on it
    width_rel: float  # lesion width / scan height
    height_rel: float  # lesion height (depth direction) / scan height
    area_share: float  # share of the visible scan covered by the lesion
    orientation: str  # "wider" (wider than tall) or "taller" (taller than wide)
    note: str


def _pad_square(img: Image.Image) -> Image.Image:
    w, h = img.size
    s = max(w, h)
    canvas = Image.new(img.mode, (s, s), 0)
    canvas.paste(img, ((s - w) // 2, (s - h) // 2))
    return canvas


def largest_component(m: np.ndarray) -> np.ndarray:
    """The largest 4-connected region of a boolean mask (same rule as the notebook)."""
    lab = np.zeros(m.shape, np.int32)
    best_label, best_n, cur = 0, 0, 0
    for y0, x0 in zip(*np.nonzero(m)):
        if lab[y0, x0]:
            continue
        cur += 1
        stack, n = [(y0, x0)], 0
        lab[y0, x0] = cur
        while stack:
            y, x = stack.pop()
            n += 1
            for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= yy < m.shape[0] and 0 <= xx < m.shape[1] and m[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = cur
                    stack.append((yy, xx))
        if n > best_n:
            best_label, best_n = cur, n
    return lab == best_label if best_label else np.zeros_like(m, bool)


def _erode(m: np.ndarray) -> np.ndarray:
    out = m.copy()
    out[1:] &= m[:-1]
    out[:-1] &= m[1:]
    out[:, 1:] &= m[:, :-1]
    out[:, :-1] &= m[:, 1:]
    return out


def draw(gray: Image.Image, mask256: np.ndarray) -> str:
    """The scan with a translucent fill and a solid edge over the lesion, cropped back to the scan's shape."""
    w, h = gray.size
    s = DRAW_SIZE
    base = np.asarray(_pad_square(gray).resize((s, s), Image.BILINEAR), np.float32)
    soft = np.asarray(Image.fromarray(mask256.astype(np.uint8) * 255).resize((s, s), Image.BILINEAR), np.float32) / 255
    inside = soft >= 0.5
    core = inside
    for _ in range(EDGE_WIDTH):
        core = _erode(core)
    edge = inside & ~core
    out = np.repeat(base[..., None], 3, -1)
    out[inside] = out[inside] * (1 - FILL_ALPHA) + OUTLINE_RGB * FILL_ALPHA
    out[edge] = OUTLINE_RGB
    sw, sh = round(w * s / max(w, h)), round(h * s / max(w, h))
    left, top = (s - sw) // 2, (s - sh) // 2
    buf = io.BytesIO()
    Image.fromarray(out.clip(0, 255).astype(np.uint8)).crop((left, top, left + sw, top + sh)).save(buf, format="JPEG", quality=88)
    return base64.b64encode(buf.getvalue()).decode()


def measure(mask256: np.ndarray, scan_size: tuple[int, int]) -> dict:
    """Bounding-box width and height relative to the scan's height, and the share of the visible scan it covers."""
    w, h = scan_size
    side = max(w, h)
    px = side / mask256.shape[0]   # original pixels per mask pixel (the mask covers the padded square)
    ys, xs = np.nonzero(mask256)
    width_rel = (xs.max() - xs.min() + 1) * px / h
    height_rel = (ys.max() - ys.min() + 1) * px / h
    area_share = mask256.sum() * px * px / (w * h)
    return {"width_rel": round(float(width_rel), 4), "height_rel": round(float(height_rel), 4),
            "area_share": round(float(min(area_share, 1.0)), 4),
            "orientation": "taller" if height_rel > width_rel else "wider"}


OUTLINE_NOTE = ("The outline is drawn by a second AI model trained on radiologists' outlines. It is approximate: it helps you "
                "see the area the result is about, but a radiologist measures the lesion properly.")


class Outliner:
    def __init__(self, session, meta: dict):
        self.session, self.meta = session, meta
        self.size = meta["input"]["size"]
        self.mean = np.array(meta["input"]["mean"], np.float32)[:, None, None]
        self.std = np.array(meta["input"]["std"], np.float32)[:, None, None]

    def mask(self, gray: Image.Image) -> np.ndarray:
        x = np.asarray(_pad_square(gray).resize((self.size, self.size), Image.BILINEAR), np.float32) / 255.0
        x = ((np.repeat(x[None], 3, 0) - self.mean) / self.std)[None].astype(np.float32)
        logits = self.session.run(None, {"image": x})[0][0, 0]
        prob = 1 / (1 + np.exp(-logits))
        m = largest_component(prob >= self.meta.get("probability_threshold", 0.5))
        return m if m.mean() >= self.meta.get("min_area_fraction", 0.0) else np.zeros_like(m)

    def outline(self, gray: Image.Image) -> LesionOutline | None:
        m = self.mask(gray)
        if not m.any():
            return None
        return LesionOutline(image_jpeg=draw(gray, m), **measure(m, gray.size), note=OUTLINE_NOTE)


def load() -> Outliner | None:
    meta_path = MODELS / "breast_seg_meta.json"
    if not meta_path.exists():
        return None
    import onnxruntime as ort
    meta = json.loads(meta_path.read_text())
    return Outliner(ort.InferenceSession(str(MODELS / meta["onnx_file"]), providers=["CPUExecutionProvider"]), meta)
