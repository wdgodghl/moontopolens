///|
/// Lower-star cubical filtration on values at grid vertices.
/// Edges/squares inherit the maximum value of their corner vertices.
/// For binary images pass 0 for foreground, 1 for background and cutoff 0.
/// This convention connects foreground horizontally/vertically, not diagonally.
pub fn cubical_grid(
  grid : Array[Array[Double]],
  threshold~ : Double,
  max_cells? : Int = 4000,
) -> Filtration raise TopologyError {
  if !finite(threshold) || threshold.abs() > 1.0e100 {
    raise TopologyError(
      "grid threshold must be finite with absolute value <= 1e100",
    )
  }
  check_budget(0, max_cells)
  let height = grid.length()
  if height == 0 {
    return finalize([], 0, "cubical", threshold)
  }
  let width = grid[0].length()
  if width < 1 || height > 64 || width > 64 {
    raise TopologyError("grid dimensions must be between 1 and 64")
  }
  for row in grid {
    if row.length() != width {
      raise TopologyError("grid must be rectangular")
    }
    for value in row {
      if !finite(value) || value.abs() > 1.0e100 {
        raise TopologyError(
          "grid values must be finite with absolute value <= 1e100",
        )
      }
    }
  }
  let raw : Array[RawCell] = []
  let mut vertex_count = 0
  for y = 0; y < height; y = y + 1 {
    for x = 0; x < width; x = x + 1 {
      let a = y * width + x
      let value = grid[y][x]
      if value > threshold {
        continue
      }
      check_budget(raw.length() + 1, max_cells)
      raw.push({
        key: vertex_key(a),
        dimension: 0,
        value,
        faces: [],
        vertices: [a],
      })
      vertex_count += 1
      if x + 1 < width {
        let b = a + 1
        let v = maximum(value, grid[y][x + 1])
        if v <= threshold {
          check_budget(raw.length() + 1, max_cells)
          raw.push({
            key: edge_key(a, b),
            dimension: 1,
            value: v,
            faces: [vertex_key(a), vertex_key(b)],
            vertices: [a, b],
          })
        }
      }
      if y + 1 < height {
        let b = a + width
        let v = maximum(value, grid[y + 1][x])
        if v <= threshold {
          check_budget(raw.length() + 1, max_cells)
          raw.push({
            key: edge_key(a, b),
            dimension: 1,
            value: v,
            faces: [vertex_key(a), vertex_key(b)],
            vertices: [a, b],
          })
        }
      }
      if x + 1 < width && y + 1 < height {
        let b = a + 1
        let c = a + width
        let d = c + 1
        let v = maximum(
          value,
          maximum(grid[y][x + 1], maximum(grid[y + 1][x], grid[y + 1][x + 1])),
        )
        if v <= threshold {
          check_budget(raw.length() + 1, max_cells)
          raw.push({
            key: "s:\{a}",
            dimension: 2,
            value: v,
            faces: [
              edge_key(a, b),
              edge_key(a, c),
              edge_key(b, d),
              edge_key(c, d),
            ],
            vertices: [a, b, c, d],
          })
        }
      }
    }
  }
  finalize(raw, vertex_count, "cubical", threshold)
}
