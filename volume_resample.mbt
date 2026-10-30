///|
fn volume_axis_indices(size : Int32, stride : Int32) -> Array[Int32] {
  let result : Array[Int32] = []
  let mut index = 0
  while index < size - 1 {
    result.push(index)
    index += stride
  }
  result.push(size - 1)
  result
}

///|
fn volume_resample_shape(
  volume : Array[Array[Array[Double]]],
) -> (Int32, Int32, Int32) raise TopologyError {
  let depth = volume.length()
  if depth < 2 || depth > 32 {
    raise TopologyError("volume depth must be between 2 and 32")
  }
  let height = volume[0].length()
  if height < 2 || height > 32 {
    raise TopologyError("volume height must be between 2 and 32")
  }
  let width = volume[0][0].length()
  if width < 2 || width > 32 {
    raise TopologyError("volume width must be between 2 and 32")
  }
  for layer in volume {
    if layer.length() != height {
      raise TopologyError("volume layers must have equal height")
    }
    for row in layer {
      if row.length() != width {
        raise TopologyError("volume layers must be rectangular")
      }
      for value in row {
        if !finite(value) || value.abs() > 1.0e100 {
          raise TopologyError("volume values must be bounded and finite")
        }
      }
    }
  }
  (depth, height, width)
}

///|
/// Reduce a vertex-valued volume to a bounded coarse grid. Endpoints are
/// retained. "sample" selects source vertices, while "mean" averages a local
/// neighborhood and may change topology; neither preserves exact persistence.
pub fn resample_volume(
  volume : Array[Array[Array[Double]]],
  stride : Int32,
  sampling~ : String = "mean",
) -> Array[Array[Array[Double]]] raise TopologyError {
  let (depth, height, width) = volume_resample_shape(volume)
  if stride < 1 || stride > 16 || (sampling != "mean" && sampling != "sample") {
    raise TopologyError(
      "volume resampling requires stride 1..16 and mean or sample",
    )
  }
  let zs = volume_axis_indices(depth, stride)
  let ys = volume_axis_indices(height, stride)
  let xs = volume_axis_indices(width, stride)
  let result : Array[Array[Array[Double]]] = []
  for z in zs {
    let layer : Array[Array[Double]] = []
    for y in ys {
      let row : Array[Double] = []
      for x in xs {
        if sampling == "sample" || stride == 1 {
          row.push(volume[z][y][x])
        } else {
          let radius = stride / 2
          let mut sum = 0.0
          let mut count = 0
          for zz = maximum_int(0, z - radius)
              zz <= minimum_int(depth - 1, z + radius)
              zz = zz + 1 {
            for yy = maximum_int(0, y - radius)
                yy <= minimum_int(height - 1, y + radius)
                yy = yy + 1 {
              for xx = maximum_int(0, x - radius)
                  xx <= minimum_int(width - 1, x + radius)
                  xx = xx + 1 {
                sum += volume[zz][yy][xx]
                count += 1
              }
            }
          }
          row.push(sum / count.to_double())
        }
      }
      layer.push(row)
    }
    result.push(layer)
  }
  result
}

///|
fn maximum_int(a : Int32, b : Int32) -> Int32 {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn minimum_int(a : Int32, b : Int32) -> Int32 {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Choose the smallest stride whose *fully dense* cubical cell count is
/// within budget. This is an explicitly approximate full-volume fallback;
/// callers can still use cubical_volume for exact sparse data.
pub fn analyze_volume_coarse(
  volume : Array[Array[Array[Double]]],
  threshold~ : Double,
  max_cells~ : Int32 = 4000,
) -> (Analysis, Int32) raise TopologyError {
  let (depth, height, width) = volume_resample_shape(volume)
  check_budget(0, max_cells)
  let mut stride = 1
  while stride <= 16 {
    let nz = volume_axis_indices(depth, stride).length()
    let ny = volume_axis_indices(height, stride).length()
    let nx = volume_axis_indices(width, stride).length()
    if (2 * nz - 1) * (2 * ny - 1) * (2 * nx - 1) <= max_cells {
      let coarse = resample_volume(volume, stride)
      return (
        analyze(
          cubical_volume(coarse, threshold~, max_cells~),
          max_homology_dimension=2,
        ),
        stride,
      )
    }
    stride += 1
  }
  raise TopologyError("volume cannot fit the requested coarse cell budget")
}

///|
pub fn analyze_volume_coarse_json(
  text : String,
) -> (Analysis, Int32) raise TopologyError {
  if text.length() > 1000000 {
    raise TopologyError("coarse volume request exceeds one million characters")
  }
  let parsed = @json.parse(text) catch {
    _ => raise TopologyError("invalid coarse volume JSON")
  }
  let fields = batch_object(parsed, "coarse volume")
  batch_fields(
    fields,
    ["kind", "threshold", "max_cells", "volume", "homology_dimension"],
    "coarse volume",
  )
  if batch_string(fields, "kind") != "volume" ||
    integer_field(fields, "homology_dimension", 2) != 2 {
    raise TopologyError("coarse volume requires volume H2 input")
  }
  let volume : Array[Array[Array[Double]]] = @json.from_json(
    required_field(fields, "volume"),
  ) catch {
    _ => raise TopologyError("coarse volume must be number matrices")
  }
  analyze_volume_coarse(
    volume,
    threshold=number_field(fields, "threshold"),
    max_cells=integer_field(fields, "max_cells", 4000),
  )
}
