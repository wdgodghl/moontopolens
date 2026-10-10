"""Optional external differential check for MoonTopoLens Rips H0/H1.

Requires GUDHI 3.13.0 and a prior `moon build --target js`. The reference
package is used only by this validation script, never by the MoonBit core.
"""

import json
import math
import subprocess
import tempfile
from pathlib import Path

try:
    import gudhi
except ImportError as exc:
    raise SystemExit("Install the optional reference dependency: pip install gudhi==3.13.0") from exc


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "_build" / "js" / "debug" / "build" / "cmd" / "main" / "main.js"
if not CLI.is_file():
    raise SystemExit("Build the JS CLI first: moon build --target js")


def coordinates(request):
    if request["kind"] == "points":
        return request["points"], None
    if request["kind"] == "matrix":
        return None, request["matrix"]
    samples = request["series"]
    dimension = request.get("dimension", 2)
    lag = request.get("lag", 1)
    stride = request.get("stride", 1)
    count = (len(samples) - 1 - (dimension - 1) * lag) // stride + 1
    return [
        [samples[i * stride + k * lag] for k in range(dimension)]
        for i in range(count)
    ], None


def moon_diagrams(request, input_path):
    input_path.write_text(json.dumps(request), encoding="utf-8")
    result = subprocess.run(
        ["node", str(CLI), "analyze", str(input_path)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
        timeout=60,
    )
    report = json.loads(result.stdout)
    return [
        sorted(
            [
                (float(bar["birth"]), None if bar["death"] is None else float(bar["death"]))
                for bar in report["intervals"]
                if bar["dimension"] == dimension
            ],
            key=lambda bar: (bar[0], math.inf if bar[1] is None else bar[1]),
        )
        for dimension in (0, 1)
    ]


def gudhi_diagrams(request):
    points, matrix = coordinates(request)
    options = {"max_edge_length": request["threshold"]}
    if points is not None:
        options["points"] = points
    else:
        options["distance_matrix"] = matrix
    tree = gudhi.RipsComplex(**options).create_simplex_tree(max_dimension=2)
    bars = tree.persistence(
        homology_coeff_field=2,
        min_persistence=0.0,
        persistence_dim_max=True,
    )
    return [
        sorted(
            [
                (float(birth), None if math.isinf(death) else float(death))
                for degree, (birth, death) in bars
                if degree == dimension
            ],
            key=lambda bar: (bar[0], math.inf if bar[1] is None else bar[1]),
        )
        for dimension in (0, 1)
    ]


def same_bars(left, right):
    if len(left) != len(right):
        return False
    for (birth_a, death_a), (birth_b, death_b) in zip(left, right):
        if not math.isclose(birth_a, birth_b, rel_tol=1e-6, abs_tol=1e-6):
            return False
        if (death_a is None) != (death_b is None):
            return False
        if death_a is not None and not math.isclose(
            death_a, death_b, rel_tol=1e-6, abs_tol=1e-6
        ):
            return False
    return True


def cases():
    for name in ("square", "rectangle", "clusters", "matrix", "periodic-series"):
        yield name, json.loads((ROOT / "examples" / f"{name}.json").read_text(encoding="utf-8"))
    for cutoff in (0.5, 1.0, 1.25, math.sqrt(2), 2.0):
        yield f"square-cutoff-{cutoff:.6g}", {
            "kind": "points",
            "points": [[0, 0], [1, 0], [1, 1], [0, 1]],
            "threshold": cutoff,
        }
    for seed in range(12):
        points = [
            [(i * 7 + seed * 3) % 11 / 3, (i * i + seed * 5) % 13 / 4]
            for i in range(6)
        ]
        yield f"deterministic-cloud-{seed}", {
            "kind": "points",
            "points": points,
            "threshold": 5.0,
        }


def main():
    checked = 0
    with tempfile.TemporaryDirectory(prefix="moontopolens-reference-") as folder:
        input_path = Path(folder) / "case.json"
        for name, request in cases():
            moon = moon_diagrams(request, input_path)
            reference = gudhi_diagrams(request)
            for degree in (0, 1):
                if not same_bars(moon[degree], reference[degree]):
                    raise AssertionError(
                        f"{name} H{degree} mismatch:\nMoonBit {moon[degree]}\nGUDHI  {reference[degree]}"
                    )
            checked += 1
    print(f"GUDHI {gudhi.__version__}: {checked} Rips cases agree in H0/H1")


if __name__ == "__main__":
    main()
