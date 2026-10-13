///|
/// Common-grid features; conditions flag compares only complex kind and cutoff.
/// Units, normalization and sampling comparability remain properties of inputs.
pub fn batch_features(
  analyses : Array[Analysis],
  names : Array[String],
  dimension~ : Int,
  start~ : Double,
  end~ : Double,
  samples? : Int = 101,
  layers? : Int = 3,
) -> (Json, String) raise TopologyError {
  if analyses.length() < 1 ||
    analyses.length() > 8 ||
    names.length() != analyses.length() {
    raise TopologyError("features require 1..8 named analyses")
  }
  if dimension < 0 ||
    dimension > 2 ||
    layers < 1 ||
    layers > 16 ||
    !finite(start) ||
    !finite(end) ||
    start.abs() > 1.0e100 ||
    end.abs() > 1.0e100 ||
    start >= end {
    raise TopologyError("invalid common feature dimension, layers or range")
  }
  let seen : Array[String] = []
  for name in names {
    batch_name(name)
    if seen.contains(name) {
      raise TopologyError("duplicate feature name")
    }
    seen.push(name)
  }
  let grid = if samples >= 2 && samples <= 1001 {
    landscape_grid(start, end, samples)
  } else {
    raise TopologyError("feature samples must be 2..1001")
  }
  let columns : Array[String] = [
    "case", "kind", "cutoff", "dimension", "censored_intervals_excluded", "finite_persistence_entropy",
    "betti_at_end",
  ]
  for i = 0; i < samples; i = i + 1 {
    columns.push("betti_\{i}")
  }
  for layer = 0; layer < layers; layer = layer + 1 {
    for i = 0; i < samples; i = i + 1 {
      columns.push("lambda_\{layer + 1}_\{i}")
    }
  }
  let mut csv = columns.join(",") + "\n"
  let rows : Array[Json] = []
  let mut same = true
  for i, analysis in analyses {
    if !finite(start) ||
      !finite(end) ||
      start >= end ||
      end > analysis.filtration.cutoff {
      raise TopologyError(
        "common feature range requires finite start < end <= every cutoff",
      )
    }
    if analysis.filtration.kind != analyses[0].filtration.kind ||
      analysis.filtration.cutoff != analyses[0].filtration.cutoff {
      same = false
    }
    let landscape = persistence_landscape(
      analysis,
      dimension~,
      start~,
      end~,
      samples~,
      layers~,
    )
    let vector : Array[Double] = []
    for layer in landscape {
      for value in layer {
        vector.push(value)
      }
    }
    let curve : Array[Int] = []
    for scale in grid {
      curve.push(betti(analysis, dimension, scale))
    }
    let finite_intervals = analysis.intervals.filter(fn(interval) {
      interval.dimension == dimension && interval.death is Some(_)
    })
    let excluded = analysis.intervals
      .filter(fn(interval) {
        interval.dimension == dimension && interval.death is None
      })
      .length()
    let mut total = 0.0
    for interval in finite_intervals {
      total += observed_lifetime(analysis, interval)
    }
    let mut entropy = 0.0
    if total > 0.0 {
      for interval in finite_intervals {
        let p = observed_lifetime(analysis, interval) / total
        if p > 0.0 {
          entropy -= p * @math.ln(p)
        }
      }
    }
    csv += "\{names[i]},\{analysis.filtration.kind},\{analysis.filtration.cutoff},\{dimension},\{excluded},\{entropy},\{betti(analysis, dimension, end)}"
    for value in curve {
      csv += ",\{value}"
    }
    for value in vector {
      csv += ",\{value}"
    }
    csv += "\n"
    rows.push({
      "name": names[i],
      "kind": analysis.filtration.kind,
      "cutoff": analysis.filtration.cutoff,
      "dimension": dimension,
      "censored_intervals_excluded": excluded,
      "finite_persistence_entropy": entropy,
      "betti_at_end": betti(analysis, dimension, end),
      "betti_vector": curve,
      "landscape_vector": vector,
    })
  }
  (
    {
      "schema_version": 1,
      "dimension": dimension,
      "start": start,
      "end": end,
      "samples": samples,
      "layers": layers,
      "grid": grid,
      "columns": columns,
      "rows": rows,
      "complex_kinds_and_cutoffs_equal": same,
      "landscape_order": "layer-major, increasing scale",
      "entropy_scope": "all finite intervals through each input cutoff",
      "note": "Betti includes censored intervals; landscape and entropy exclude them. Equal kind and cutoff do not establish equal units, preprocessing or sampling.",
    },
    csv,
  )
}
