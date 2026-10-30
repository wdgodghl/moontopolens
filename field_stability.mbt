///|
fn field_shift(trial : Int32, index : Int32, epsilon : Double) -> Double {
  let code = ((trial + 1) * (index + 3) * 37 + (index + 11) * 19) % 211
  (code.to_double() / 105.0 - 1.0) * epsilon
}

///|
/// Repeat a grid or volume analysis after deterministic bounded intensity
/// perturbations. Distances describe sensitivity, not statistical confidence.
pub fn field_stability_json(
  text : String,
  epsilon : Double,
  trials~ : Int32 = 6,
) -> Json raise TopologyError {
  if !finite(epsilon) || epsilon < 0.0 || epsilon > 1.0e6 {
    raise TopologyError("field stability epsilon must be in [0,1e6]")
  }
  if trials < 1 || trials > 12 {
    raise TopologyError("field stability trials must be between 1 and 12")
  }
  if text.length() > 1000000 {
    raise TopologyError("field stability input exceeds one million characters")
  }
  let parsed = @json.parse(text) catch {
    _ => raise TopologyError("invalid field stability JSON")
  }
  let fields = batch_object(parsed, "field stability")
  let kind = batch_string(fields, "kind")
  if kind != "grid" && kind != "volume" {
    raise TopologyError("field stability requires grid or volume input")
  }
  let threshold = number_field(fields, "threshold")
  let budget = integer_field(fields, "max_cells", 4000)
  let baseline = analyze_json(text)
  let max_dimension = if kind == "volume" { 2 } else { 1 }
  let grid : Array[Array[Double]] = if kind == "grid" {
    rows_field(fields, "grid")
  } else {
    []
  }
  let volume : Array[Array[Array[Double]]] = if kind == "volume" {
    @json.from_json(required_field(fields, "volume")) catch {
      _ => raise TopologyError("volume must be number matrices")
    }
  } else {
    []
  }
  let results : Array[Json] = []
  let mut total_cells = 0
  let max_distance : Array[Double] = Array::make(max_dimension + 1, 0.0)
  for trial = 0; trial < trials; trial = trial + 1 {
    let perturbed = if kind == "grid" {
      let changed = Array::makei(grid.length(), fn(y) {
        Array::makei(grid[y].length(), fn(x) {
          grid[y][x] + field_shift(trial, y * grid[0].length() + x, epsilon)
        })
      })
      analyze(cubical_grid(changed, threshold~, max_cells=budget))
    } else {
      let height = volume[0].length()
      let width = volume[0][0].length()
      let changed = Array::makei(volume.length(), fn(z) {
        Array::makei(height, fn(y) {
          Array::makei(width, fn(x) {
            volume[z][y][x] +
            field_shift(trial, (z * height + y) * width + x, epsilon)
          })
        })
      })
      analyze(
        cubical_volume(changed, threshold~, max_cells=budget),
        max_homology_dimension=2,
      )
    }
    total_cells += perturbed.filtration.cells.length()
    if total_cells > 24000 {
      raise TopologyError("field stability exceeds 24000 total cells")
    }
    let distances : Array[Json] = []
    let counts : Array[Int32] = []
    for dimension = 0; dimension <= max_dimension; dimension = dimension + 1 {
      let distance = compare_analyses(baseline, perturbed, dimension~)
      distances.push(volume_sequence_optional(distance))
      counts.push(betti(perturbed, dimension, threshold))
      match distance {
        Some(value) =>
          max_distance[dimension] = maximum(max_distance[dimension], value)
        None => ()
      }
    }
    results.push({
      "trial": trial + 1,
      "cell_count": perturbed.filtration.cells.length(),
      "bottleneck_by_dimension": distances,
      "betti_at_cutoff": counts,
    })
  }
  let baseline_counts : Array[Int32] = []
  for dimension = 0; dimension <= max_dimension; dimension = dimension + 1 {
    baseline_counts.push(betti(baseline, dimension, threshold))
  }
  {
    "schema_version": 1,
    "kind": "field_stability",
    "source_kind": kind,
    "threshold": threshold,
    "epsilon": epsilon,
    "trials": trials,
    "baseline_betti_at_cutoff": baseline_counts,
    "max_finite_bottleneck_by_dimension": max_distance,
    "cases": results,
    "interpretation": "deterministic bounded intensity perturbations; null means no finite matching of cutoff-censored classes; this is not a probability or confidence interval",
  }
}
