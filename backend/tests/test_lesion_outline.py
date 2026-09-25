import base64
import io

import numpy as np
from PIL import Image

import lesion_outline as lo


class FakeSession:
    """Returns high logits inside a fixed box of the 256 x 256 padded square, low elsewhere."""

    def __init__(self, box):
        self.box = box

    def run(self, _, feeds):
        assert feeds["image"].shape == (1, 3, 256, 256)
        y0, y1, x0, x1 = self.box
        out = np.full((1, 1, 256, 256), -8.0, np.float32)
        out[0, 0, y0:y1, x0:x1] = 8.0
        return [out]


META = {"input": {"size": 256, "mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225]},
        "probability_threshold": 0.5, "min_area_fraction": 0.002}


def test_largest_component_keeps_only_the_biggest_region():
    m = np.zeros((20, 20), bool)
    m[1:3, 1:3] = True
    m[10:16, 10:18] = True
    out = lo.largest_component(m)
    assert out.sum() == 48 and not out[1, 1]


def test_outline_measures_relative_size_and_orientation():
    # a 400 x 200 scan is padded to 400 x 400; the box is 64 mask px wide (= 100 px) and 32 tall (= 50 px)
    gray = Image.new("L", (400, 200), 90)
    result = lo.Outliner(FakeSession((112, 144, 96, 160)), META).outline(gray)
    assert result is not None
    assert abs(result.width_rel - 0.5) < 0.01 and abs(result.height_rel - 0.25) < 0.01   # relative to the 200 px height
    assert result.orientation == "wider"
    assert abs(result.area_share - (100 * 50) / (400 * 200)) < 0.005
    img = Image.open(io.BytesIO(base64.b64decode(result.image_jpeg)))
    assert img.size == (512, 256)   # cropped back to the scan's shape
    px = np.asarray(img.convert("RGB"), np.int16)
    assert (px[..., 0] - px[..., 1] > 100).any()   # the magenta edge is drawn


def test_tiny_or_empty_prediction_gives_no_outline():
    gray = Image.new("L", (300, 300), 90)
    assert lo.Outliner(FakeSession((0, 0, 0, 0)), META).outline(gray) is None
    assert lo.Outliner(FakeSession((10, 12, 10, 12)), META).outline(gray) is None   # 4 px, below the minimum area


def test_taller_than_wide():
    gray = Image.new("L", (256, 256), 90)
    assert lo.Outliner(FakeSession((50, 150, 100, 140)), META).outline(gray).orientation == "taller"


def test_no_model_files_means_no_outliner(monkeypatch, tmp_path):
    monkeypatch.setattr(lo, "MODELS", tmp_path)
    assert lo.load() is None
