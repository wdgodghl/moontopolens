///|
fn volume_face_key(axis : String, start : Int32) -> String {
  "vf:\{axis}:\{start}"
}

///|
fn volume_cell(
  raw : Array[RawCell],
  values : Array[Double],
  vertices : Array[Int32],
  faces : Array[String],
  key : String,
  dimension : Int32,
  threshold : Double,
  max_cells : Int32,
) -> Unit raise TopologyError {
  let mut value = values[vertices[0]]
  for vertex in vertices {
    value = maximum(value, values[vertex])
  }
  if value <= threshold {
    check_budget(raw.length() + 1, max_cells)
    raw.push({ key, dimension, value, faces, vertices, })
  }
}

///|
/// A 3D lower-star cubical complex on values at voxel-grid vertices.
/// The input is volume[z][y][x]; only cells at or below threshold are stored.
/// Faces inherit the maximum value of their corner vertices.
pub fn cubical_volume(
  volume : Array[Array[Array[Double]]],
  threshold~ : Double,
  max_cells~ : Int32 = 4000,
) -> Filtration raise TopologyError {
  if !finite(threshold) || threshold.abs() > 1.0e100 {
    raise TopologyError("volume threshold must be bounded and finite")
  }
  check_budget(0, max_cells)
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
  let values : Array[Double] = []
  for layer in volume {
    if layer.length() != height {
      raise TopologyError("volume must have equal-sized layers")
    }
    for row in layer {
      if row.length() != width {
        raise TopologyError("volume layers must be rectangular")
      }
      for value in row {
        if !finite(value) || value.abs() > 1.0e100 {
          raise TopologyError("volume values must be bounded and finite")
        }
        values.push(value)
      }
    }
  }
  let plane = width * height
  let raw : Array[RawCell] = []
  let mut vertex_count = 0
  for z = 0; z < depth; z = z + 1 {
    for y = 0; y < height; y = y + 1 {
      for x = 0; x < width; x = x + 1 {
        let a = z * plane + y * width + x
        // Every cell anchored here contains this vertex. Skip all allocations
        // when it cannot enter the filtration, which helps sparse large grids.
        if values[a] > threshold {
          continue
        }
        vertex_count += 1
        volume_cell(
          raw,
          values,
          [a],
          [],
          vertex_key(a),
          0,
          threshold,
          max_cells,
        )
        if x + 1 < width {
          let b = a + 1
          volume_cell(
            raw,
            values,
            [a, b],
            [vertex_key(a), vertex_key(b)],
            edge_key(a, b),
            1,
            threshold,
            max_cells,
          )
        }
        if y + 1 < height {
          let c = a + width
          volume_cell(
            raw,
            values,
            [a, c],
            [vertex_key(a), vertex_key(c)],
            edge_key(a, c),
            1,
            threshold,
            max_cells,
          )
        }
        if z + 1 < depth {
          let e = a + plane
          volume_cell(
            raw,
            values,
            [a, e],
            [vertex_key(a), vertex_key(e)],
            edge_key(a, e),
            1,
            threshold,
            max_cells,
          )
        }
        if x + 1 < width && y + 1 < height {
          let b = a + 1
          let c = a + width
          let d = c + 1
          volume_cell(
            raw,
            values,
            [a, b, c, d],
            [edge_key(a, b), edge_key(a, c), edge_key(b, d), edge_key(c, d)],
            volume_face_key("xy", a),
            2,
            threshold,
            max_cells,
          )
        }
        if x + 1 < width && z + 1 < depth {
          let b = a + 1
          let e = a + plane
          let f = e + 1
          volume_cell(
            raw,
            values,
            [a, b, e, f],
            [edge_key(a, b), edge_key(a, e), edge_key(b, f), edge_key(e, f)],
            volume_face_key("xz", a),
            2,
            threshold,
            max_cells,
          )
        }
        if y + 1 < height && z + 1 < depth {
          let c = a + width
          let e = a + plane
          let g = e + width
          volume_cell(
            raw,
            values,
            [a, c, e, g],
            [edge_key(a, c), edge_key(a, e), edge_key(c, g), edge_key(e, g)],
            volume_face_key("yz", a),
            2,
            threshold,
            max_cells,
          )
        }
        if x + 1 < width && y + 1 < height && z + 1 < depth {
          let b = a + 1
          let c = a + width
          let d = c + 1
          let e = a + plane
          let f = e + 1
          let g = e + width
          let h = g + 1
          volume_cell(
            raw,
            values,
            [a, b, c, d, e, f, g, h],
            [
              volume_face_key("xy", a),
              volume_face_key("xy", e),
              volume_face_key("xz", a),
              volume_face_key("xz", c),
              volume_face_key("yz", a),
              volume_face_key("yz", b),
            ],
            "vc:\{a}",
            3,
            threshold,
            max_cells,
          )
        }
      }
    }
  }
  let positions = Array::makei(values.length(), fn(i) {
    [
      (i % width).to_double(),
      -(i / width % height).to_double(),
      (i / plane).to_double(),
    ]
  })
  finalize(raw, vertex_count, "cubical_volume", threshold, positions~)
}
