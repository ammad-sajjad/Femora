import itertools
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import app as backend  # noqa: E402

client = TestClient(backend.app)

BASE = {
    "age": 24, "height_cm": 165, "weight_kg": 70, "irregular_cycle": True, "period_days": 5, "weight_gain": True,
    "hair_growth": True, "skin_darkening": True, "hair_loss": False, "pimples": True, "fast_food": True, "regular_exercise": False,
}


def whatif(answers, scenarios):
    return client.post("/predict/pcos/whatif", json={"answers": answers, "scenarios": scenarios})


def test_the_normal_prediction_is_unchanged_by_the_refactor():
    r = client.post("/predict/pcos", json=BASE).json()
    assert r["probability"] == pytest.approx(0.979, abs=0.002)
    assert r["risk_level"] == "high"
    assert r["bmi"] == 25.7
    assert [f["label"] for f in r["factors"]][0] == "BMI 25.7"


def test_the_baseline_equals_the_normal_prediction_and_an_empty_scenario_changes_nothing():
    normal = client.post("/predict/pcos", json=BASE).json()
    r = whatif(BASE, [{"label": "Nothing changed"}]).json()
    assert r["baseline_probability"] == normal["probability"]
    assert r["baseline_risk_level"] == normal["risk_level"]
    assert r["outcomes"][0]["change_points"] == 0
    assert r["outcomes"][0]["probability"] == normal["probability"]
    assert "small study of 541 women" in r["note"]


def test_bmi_is_recomputed_from_the_new_weight():
    r = whatif(BASE, [{"label": "Lighter", "weight_kg": 60}]).json()
    assert r["outcomes"][0]["bmi"] == 22.0  # 60 / 1.65 squared


def test_several_scenarios_come_back_in_order_with_their_labels():
    r = whatif(BASE, [{"label": "A", "regular_exercise": True}, {"label": "B", "fast_food": False}, {"label": "C", "weight_kg": 65}]).json()
    assert [o["label"] for o in r["outcomes"]] == ["A", "B", "C"]
    assert all(0 <= o["probability"] <= 1 for o in r["outcomes"])
    assert all(o["risk_level"] in ("low", "medium", "high") for o in r["outcomes"])


def test_risk_level_follows_the_bands():
    r = whatif(BASE, [{"label": "x", "regular_exercise": True}]).json()["outcomes"][0]
    p = r["probability"]
    assert r["risk_level"] == ("low" if p < 0.3 else "medium" if p < 0.6 else "high")


def _answers():
    """A spread of answer sets: every yes/no symptom on and off in turn, with different builds and habits."""
    for irregular, gain, hair, dark, pimples in itertools.product([False, True], repeat=5):
        for weight, fast, exercise in [(52, False, True), (62, True, False), (78, True, False), (90, False, False)]:
            yield {**BASE, "irregular_cycle": irregular, "weight_gain": gain, "hair_growth": hair, "skin_darkening": dark, "pimples": pimples,
                   "weight_kg": weight, "fast_food": fast, "regular_exercise": exercise}


def test_the_model_only_moves_the_way_it_was_built_to():
    """Exercise never raises the estimate; less fast food and a lower weight never raise it either (monotone constraints)."""
    checked = 0
    for a in _answers():
        r = whatif(a, [
            {"label": "exercise", "regular_exercise": True},
            {"label": "no fast food", "fast_food": False},
            {"label": "lighter", "weight_kg": max(25, a["weight_kg"] - 8)},
            {"label": "all", "regular_exercise": True, "fast_food": False, "weight_kg": max(25, a["weight_kg"] - 8)},
        ]).json()
        for o in r["outcomes"]:
            assert o["change_points"] <= 0.05, (a, o)
        allo = r["outcomes"][-1]["probability"]
        assert allo <= min(o["probability"] for o in r["outcomes"][:-1]) + 1e-4, (a, r)
        checked += 1
    assert checked == 128


def test_a_waist_change_needs_both_waist_and_hip_to_matter():
    without = whatif(BASE, [{"label": "w", "waist_in": 28}]).json()["outcomes"][0]
    assert without["change_points"] == 0  # no hip measurement: the waist-to-hip ratio stays at the study's typical value
    with_hip = {**BASE, "waist_in": 36, "hip_in": 38}
    slimmer = whatif(with_hip, [{"label": "w", "waist_in": 30}]).json()["outcomes"][0]
    assert isinstance(slimmer["probability"], float)


@pytest.mark.parametrize("body", [
    {"answers": BASE, "scenarios": []},
    {"answers": BASE, "scenarios": [{"label": "x"}] * 9},
    {"answers": BASE, "scenarios": [{"label": "", "weight_kg": 60}]},
    {"answers": BASE, "scenarios": [{"label": "x", "weight_kg": 10}]},
    {"answers": BASE, "scenarios": [{"label": "x", "weight_kg": 500}]},
    {"answers": BASE, "scenarios": [{"label": "x" * 61}]},
    {"scenarios": [{"label": "x"}]},
    {"answers": {**BASE, "age": 5}, "scenarios": [{"label": "x"}]},
])
def test_bad_requests_are_refused_with_422(body):
    assert client.post("/predict/pcos/whatif", json=body).status_code == 422
