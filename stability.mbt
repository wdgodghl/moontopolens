///|
/// Deterministic bounded coordinate jitter. This is a sensitivity experiment,
/// not a probability model or a guarantee that a geometric feature is real.
pub fn point_stability_json(
  text : String,
  epsilon : Double,
  trials~ : Int32 = 8,
) -> Json raise TopologyError {
  if !finite(epsilon) || epsilon < 0.0 || epsilon > 1.0e6 {
    raise TopologyError(
      "stability epsilon must be finite and between 0 and 1e6",
    )
  }
  if trials < 1 || trials > 12 {
    raise TopologyError("stability trials must be between 1 and 12")
  }
  if text.length() > 1000000 {
    raise TopologyError("stability input exceeds one million characters")
  }
  let parsed = @json.parse(text) catch {
    _ => raise TopologyError("invalid stability JSON")
  }
  let fields = match parsed {
    Object(value) => value
    _ => raise TopologyError("stability input must be a JSON object")
  }
  let kind : String = @json.from_json(required_field(fields, "kind")) catch {
    _ => raise TopologyError("kind must be a string")
  }
  if kind != "points" {
    raise TopologyError("coordinate stability currently requires kind points")
  }
  let points = rows_field(fields, "points")
  if points.is_empty() {
    raise TopologyError("stability requires at least one point")
  }
  if integer_field(fields, "homology_dimension", 1) != 1 {
    raise TopologyError("stability currently compares H0/H1 point analyses")
  }
  let threshold = number_field(fields, "threshold")
  let budget = integer_field(fields, "max_cells", 4000)
  let baseline = analyze_json(text)
  if points.length() > 24 {
    raise TopologyError("stability supports at most 24 points")
  }
  let h1_indices : Array[Int32] = []
  for index, interval in baseline.intervals {
    if interval.dimension == 1 {
      h1_indices.push(index)
    }
  }
  let retained = Array::make(h1_indices.length(), 0)
  let cases : Array[Json] = []
  let mut total_cells = 0
  let tolerance = 2.0 * epsilon * points[0].length().to_double().sqrt()
  for trial = 0; trial < trials; trial = trial + 1 {
    let perturbed = Array::makei(points.length(), fn(i) {
      Array::makei(points[i].length(), fn(j) {
        let code = (
            (trial + 1) * (i + 3) * 37 +
            (j + 1) * (trial + 5) * 29 +
            (i * j + 1) * 11
          ) %
          211
        let shift = (code.to_double() / 105.0 - 1.0) * epsilon
        points[i][j] + shift
      })
    })
    let result = analyze(rips(perturbed, threshold~, max_cells=budget))
    total_cells += result.filtration.cells.length()
    if total_cells > 24000 {
      raise TopologyError("stability study exceeds 24000 total cells")
    }
    let h0 = compare_analyses(baseline, result, dimension=0)
    let h1 = compare_analyses(baseline, result, dimension=1)
    for pair in interval_matching(baseline, result, dimension=1) {
      if pair.left is Some(index) &&
        pair.right is Some(_) &&
        pair.cost is Some(cost) &&
        cost <= tolerance {
        for position, original in h1_indices {
          if original == index {
            retained[position] += 1
          }
        }
      }
    }
    cases.push({
      "trial": trial + 1,
      "h0_bottleneck": match h0 {
        Some(value) => value.to_json()
        None => Json::null()
      },
      "h1_bottleneck": match h1 {
        Some(value) => value.to_json()
        None => Json::null()
      },
      "h1_at_cutoff": betti(result, 1, threshold),
      "cell_count": result.filtration.cells.length(),
    })
  }
  let features : Array[Json] = []
  for position, index in h1_indices {
    let interval = baseline.intervals[index]
    features.push({
      "interval_index": index,
      "birth": interval.birth,
      "death": match interval.death {
        Some(value) => value.to_json()
        None => Json::null()
      },
      "observed_lifetime": observed_lifetime(baseline, interval),
      "retained_trials": retained[position],
      "trial_count": trials,
    })
  }
  {
    "schema_version": 1,
    "kind": "point_stability",
    "point_count": points.length(),
    "dimension": points[0].length(),
    "threshold": threshold,
    "epsilon": epsilon,
    "trials": trials,
    "matching_tolerance": tolerance,
    "baseline_h1_count": h1_indices.length(),
    "features": features,
    "cases": cases,
    "interpretation": "deterministic bounded coordinate perturbations; retained_trials counts one optimal H1 matching under the stated tolerance and is not a probability or statistical significance claim",
  }
}
