///|
fn sweep_integer_list(
  object : Map[String, Json],
  name : String,
  lower : Int,
  upper : Int,
) -> Array[Int] raise TopologyError {
  let values : Array[Json] = @json.from_json(required_field(object, name)) catch {
    _ => raise TopologyError(name + " must be an array of integers")
  }
  if values.is_empty() || values.length() > 12 {
    raise TopologyError(name + " must contain 1..12 values")
  }
  let result : Array[Int] = []
  for value in values {
    let number = match value {
      Number(n, ..) => n
      _ => raise TopologyError(name + " must contain only integers")
    }
    if !finite(number) ||
      number < lower.to_double() ||
      number > upper.to_double() ||
      number != @math.floor(number) {
      raise TopologyError(name + " contains an out-of-range integer")
    }
    let item = number.to_int()
    if result.contains(item) {
      raise TopologyError(name + " contains a duplicate value")
    }
    result.push(item)
  }
  result
}

///|
/// Evaluate a bounded Cartesian sweep of delay-embedding parameters. Every
/// vector uses the same H1 landscape grid and excludes cutoff-censored bars.
/// The returned CSV tables share the JSON case order.
pub fn series_sweep(
  text : String,
) -> (Json, String, String) raise TopologyError {
  if text.length() > 1000000 {
    raise TopologyError("series sweep request exceeds one million characters")
  }
  let value = @json.parse(text) catch {
    _ => raise TopologyError("invalid series sweep JSON")
  }
  let object = match value {
    Object(fields) => fields
    _ => raise TopologyError("series sweep request must be an object")
  }
  let kind : String = @json.from_json(required_field(object, "kind")) catch {
    _ => raise TopologyError("kind must be a string")
  }
  if kind != "series_sweep" {
    raise TopologyError("kind must be series_sweep")
  }
  for field in object.keys() {
    if ![
        "kind", "series", "threshold", "dimensions", "lags", "stride", "max_cells",
      ].contains(field) {
      raise TopologyError("unknown series sweep field: " + field)
    }
  }
  let series : Array[Double] = @json.from_json(required_field(object, "series")) catch {
    _ => raise TopologyError("series must be an array of numbers")
  }
  let threshold = number_field(object, "threshold")
  if !finite(threshold) || threshold <= 0.0 || threshold > 1.0e100 {
    raise TopologyError("sweep threshold must be finite and positive")
  }
  let dimensions = sweep_integer_list(object, "dimensions", 1, 32)
  let lags = sweep_integer_list(object, "lags", 1, 10000)
  if dimensions.length() * lags.length() > 12 {
    raise TopologyError(
      "series sweep supports at most 12 parameter combinations",
    )
  }
  let stride = integer_field(object, "stride", 1)
  let budget = integer_field(object, "max_cells", 4000)
  let grid = landscape_grid(0.0, threshold, 101)
  let cases : Array[Json] = []
  let mut summary_csv = "dimension,lag,stride,point_count,cell_count,h1_finite_count,h1_alive_at_cutoff,longest_h1_observed_lifetime,h1_at_cutoff\n"
  let mut vector_csv = "dimension,lag,stride"
  for layer = 1; layer <= 3; layer = layer + 1 {
    for sample = 0; sample < 101; sample = sample + 1 {
      vector_csv += ",lambda_\{layer}_sample_\{sample}"
    }
  }
  vector_csv += "\n"
  let mut total_cells = 0
  for dimension in dimensions {
    for lag in lags {
      let points = delay_embed(series, dimension~, lag~, stride~)
      let analysis = analyze(rips(points, threshold~, max_cells=budget))
      let cell_count = analysis.filtration.cells.length()
      total_cells += cell_count
      if total_cells > 16000 {
        raise TopologyError("series sweep exceeds 16000 total filtration cells")
      }
      let mut finite_count = 0
      let mut alive_count = 0
      let mut longest_observed = 0.0
      for interval in analysis.intervals {
        if interval.dimension != 1 {
          continue
        }
        if interval.death is None {
          alive_count += 1
        } else {
          finite_count += 1
        }
        longest_observed = maximum(
          longest_observed,
          observed_lifetime(analysis, interval),
        )
      }
      let landscape = persistence_landscape(
        analysis,
        dimension=1,
        start=0.0,
        end=threshold,
      )
      let vector : Array[Double] = []
      for layer in landscape {
        for sample in layer {
          vector.push(sample)
        }
      }
      let h1_at_cutoff = betti(analysis, 1, threshold)
      cases.push({
        "dimension": dimension,
        "lag": lag,
        "stride": stride,
        "point_count": points.length(),
        "cell_count": cell_count,
        "h1_finite_count": finite_count,
        "h1_alive_at_cutoff": alive_count,
        "longest_h1_observed_lifetime": longest_observed,
        "h1_at_cutoff": h1_at_cutoff,
        "h1_landscape_vector": vector,
      })
      summary_csv += "\{dimension},\{lag},\{stride},\{points.length()},\{cell_count},\{finite_count},\{alive_count},\{longest_observed},\{h1_at_cutoff}\n"
      vector_csv += "\{dimension},\{lag},\{stride}"
      for sample in vector {
        vector_csv += ",\{sample}"
      }
      vector_csv += "\n"
    }
  }
  (
    {
      "schema_version": 1,
      "kind": "series_sweep",
      "threshold": threshold,
      "dimensions": dimensions,
      "lags": lags,
      "stride": stride,
      "case_count": cases.length(),
      "total_cells": total_cells,
      "landscape": {
        "homology_dimension": 1,
        "samples": 101,
        "layers": 3,
        "grid": grid,
        "vector_order": "layer-major, then increasing scale",
        "normalization": "none; raw tent heights",
        "censoring": "alive-at-cutoff intervals are excluded from landscape vectors",
      },
      "cases": cases,
      "interpretation": "parameter sensitivity only; dimensions and lags change the embedded point cloud and may change its point count",
    },
    summary_csv,
    vector_csv,
  )
}
