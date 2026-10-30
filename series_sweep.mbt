///|
priv struct SweepCandidate {
  dimension : Int32
  lag : Int32
  stride : Int32
  point_count : Int32
  finite_h1_count : Int32
  longest_finite_h1_lifetime : Double
}

///|
fn sweep_integer_list(
  object : Map[String, Json],
  name : String,
  lower : Int32,
  upper : Int32,
) -> Array[Int32] raise TopologyError {
  let values : Array[Json] = @json.from_json(required_field(object, name)) catch {
    _ => raise TopologyError(name + " must be an array of integers")
  }
  if values.is_empty() || values.length() > 12 {
    raise TopologyError(name + " must contain 1..12 values")
  }
  let result : Array[Int32] = []
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
  let candidates : Array[SweepCandidate] = []
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
      let mut longest_finite = 0.0
      for interval in analysis.intervals {
        if interval.dimension != 1 {
          continue
        }
        if interval.death is None {
          alive_count += 1
        } else {
          finite_count += 1
          longest_finite = maximum(
            longest_finite,
            observed_lifetime(analysis, interval),
          )
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
        "longest_finite_h1_lifetime": longest_finite,
        "h1_at_cutoff": h1_at_cutoff,
        "h1_landscape_vector": vector,
      })
      if finite_count > 0 {
        candidates.push({
          dimension,
          lag,
          stride,
          point_count: points.length(),
          finite_h1_count: finite_count,
          longest_finite_h1_lifetime: longest_finite,
        })
      }
      summary_csv += "\{dimension},\{lag},\{stride},\{points.length()},\{cell_count},\{finite_count},\{alive_count},\{longest_observed},\{h1_at_cutoff}\n"
      vector_csv += "\{dimension},\{lag},\{stride}"
      for sample in vector {
        vector_csv += ",\{sample}"
      }
      vector_csv += "\n"
    }
  }
  candidates.sort_by(fn(a, b) {
    if a.longest_finite_h1_lifetime > b.longest_finite_h1_lifetime {
      -1
    } else if a.longest_finite_h1_lifetime < b.longest_finite_h1_lifetime {
      1
    } else if a.finite_h1_count != b.finite_h1_count {
      b.finite_h1_count - a.finite_h1_count
    } else if a.dimension != b.dimension {
      a.dimension - b.dimension
    } else {
      a.lag - b.lag
    }
  })
  let recommendations : Array[Json] = []
  for i = 0; i < candidates.length() && i < 3; i = i + 1 {
    let candidate = candidates[i]
    recommendations.push({
      "rank": i + 1,
      "dimension": candidate.dimension,
      "lag": candidate.lag,
      "stride": candidate.stride,
      "point_count": candidate.point_count,
      "finite_h1_count": candidate.finite_h1_count,
      "longest_finite_h1_lifetime": candidate.longest_finite_h1_lifetime,
      "reason": "ranked by longest finite H1 lifetime, then finite H1 count; only among the supplied combinations",
    })
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
      "recommended_parameters": recommendations,
      "recommendation_note": "exploratory ordering of supplied combinations only; no automatic period estimate, lag optimum or embedding-dimension guarantee; different combinations may contain different point counts",
      "interpretation": "parameter sensitivity only; dimensions and lags change the embedded point cloud and may change its point count",
    },
    summary_csv,
    vector_csv,
  )
}
