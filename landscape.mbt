///|
fn landscape_grid(start : Double, end : Double, samples : Int) -> Array[Double] {
  Array::makei(samples, fn(i) {
    if i == samples - 1 {
      end
    } else {
      start + (end - start) * i.to_double() / (samples - 1).to_double()
    }
  })
}

///|
/// Raw persistence landscape samples, layer-major, without normalization.
/// lambda_k(t) is the kth largest max(0, min(t-birth, death-t)).
/// Censored intervals are excluded; use identical ranges when comparing vectors.
pub fn persistence_landscape(
  analysis : Analysis,
  dimension~ : Int,
  start~ : Double,
  end~ : Double,
  samples? : Int = 101,
  layers? : Int = 3,
) -> Array[Array[Double]] raise TopologyError {
  if dimension < 0 ||
    dimension > 1 ||
    !finite(start) ||
    !finite(end) ||
    start.abs() > 1.0e100 ||
    end.abs() > 1.0e100 ||
    start >= end ||
    samples < 2 ||
    samples > 1001 ||
    layers < 1 ||
    layers > 16 {
    raise TopologyError(
      "landscape requires dimension 0/1, finite start < end, 2..1001 samples and 1..16 layers",
    )
  }
  let points = diagram(analysis, dimension)
  if points.length() * samples * layers > 2000000 {
    raise TopologyError(
      "landscape evaluation exceeds two million insertion steps; reduce samples or layers",
    )
  }
  let grid = landscape_grid(start, end, samples)
  let result = Array::makei(layers, fn(_) { Array::make(samples, 0.0) })
  for i = 0; i < samples; i = i + 1 {
    for point in points {
      let left = grid[i] - point.0
      let right = point.1 - grid[i]
      let mut value = maximum(0.0, if left < right { left } else { right })
      for layer = 0; layer < layers; layer = layer + 1 {
        if value > result[layer][i] {
          let previous = result[layer][i]
          result[layer][i] = value
          value = previous
        }
      }
    }
  }
  result
}

///|
/// Feature vector with explicit grid, order and censoring metadata.
pub fn landscape_json(
  analysis : Analysis,
  dimension~ : Int,
  start~ : Double,
  end~ : Double,
  samples? : Int = 101,
  layers? : Int = 3,
) -> Json raise TopologyError {
  let values = persistence_landscape(
    analysis,
    dimension~,
    start~,
    end~,
    samples~,
    layers~,
  )
  let vector : Array[Double] = []
  for layer in values {
    for value in layer {
      vector.push(value)
    }
  }
  let censored = analysis.intervals
    .filter(fn(interval) {
      interval.dimension == dimension && interval.death is None
    })
    .length()
  {
    "schema_version": 1,
    "feature": "persistence_landscape",
    "dimension": dimension,
    "start": start,
    "end": end,
    "samples": samples,
    "layers": layers,
    "cutoff": analysis.filtration.cutoff,
    "censored_intervals_excluded": censored,
    "grid": landscape_grid(start, end, samples),
    "values": values,
    "vector": vector,
    "vector_order": "layer-major, each layer in increasing scale order",
    "normalization": "none; raw tent heights",
    "note": "finite intervals only; identical dimensions, ranges, samples, layers and units are required for comparable vectors",
  }
}

///|
pub fn landscape_csv(
  analysis : Analysis,
  dimension~ : Int,
  start~ : Double,
  end~ : Double,
  samples? : Int = 101,
  layers? : Int = 3,
) -> String raise TopologyError {
  let values = persistence_landscape(
    analysis,
    dimension~,
    start~,
    end~,
    samples~,
    layers~,
  )
  let grid = landscape_grid(start, end, samples)
  let mut text = "scale"
  for layer = 0; layer < layers; layer = layer + 1 {
    text += ",lambda_\{layer + 1}"
  }
  text += "\n"
  for i = 0; i < samples; i = i + 1 {
    text += grid[i].to_string()
    for layer in values {
      text += ",\{layer[i]}"
    }
    text += "\n"
  }
  text
}
