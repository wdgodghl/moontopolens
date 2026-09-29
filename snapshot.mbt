///|
fn snapshot_scale(
  analysis : Analysis,
  scale : Double,
) -> Unit raise TopologyError {
  if !finite(scale) ||
    scale.abs() > 1.0e100 ||
    scale > analysis.filtration.cutoff {
    raise TopologyError(
      "snapshot scale must be bounded, finite and no greater than cutoff",
    )
  }
}

///|
fn component_root(parents : Array[Int], vertex : Int) -> Int {
  let mut current = vertex
  while parents[current] != current {
    parents[current] = parents[parents[current]]
    current = parents[current]
  }
  current
}

///|
/// Connected components of the active one-skeleton, ordered by smallest vertex.
/// Vertex IDs are the original input IDs, including gaps in thresholded grids.
pub fn connected_components(
  analysis : Analysis,
  scale : Double,
) -> Array[Array[Int]] raise TopologyError {
  snapshot_scale(analysis, scale)
  let vertices : Array[Int] = []
  for cell in analysis.filtration.cells {
    if cell.value > scale {
      break
    }
    if cell.dimension == 0 {
      if cell.vertices.length() != 1 {
        raise TopologyError(
          "components require one input vertex ID per zero-cell",
        )
      }
      vertices.push(cell.vertices[0])
    }
  }
  vertices.sort()
  let indices : Map[Int, Int] = Map([])
  for i = 0; i < vertices.length(); i = i + 1 {
    if indices.contains(vertices[i]) {
      raise TopologyError("components require unique zero-cell vertex IDs")
    }
    indices[vertices[i]] = i
  }
  let parents = Array::makei(vertices.length(), fn(i) { i })
  for cell in analysis.filtration.cells {
    if cell.value > scale {
      break
    }
    if cell.dimension != 1 {
      continue
    }
    if cell.vertices.length() != 2 {
      raise TopologyError("components require two input vertex IDs per edge")
    }
    let a = match indices.get(cell.vertices[0]) {
      Some(i) => component_root(parents, i)
      None => raise TopologyError("edge endpoint is not an active vertex")
    }
    let b = match indices.get(cell.vertices[1]) {
      Some(i) => component_root(parents, i)
      None => raise TopologyError("edge endpoint is not an active vertex")
    }
    // Always attach the larger root to the smaller; roots preserve input order.
    if a < b {
      parents[b] = a
    } else {
      parents[a] = b
    }
  }
  let groups : Array[Array[Int]] = []
  let group_indices : Map[Int, Int] = Map([])
  for i = 0; i < vertices.length(); i = i + 1 {
    let root = component_root(parents, i)
    match group_indices.get(root) {
      Some(group) => groups[group].push(vertices[i])
      None => {
        group_indices[root] = groups.length()
        groups.push([vertices[i]])
      }
    }
  }
  groups
}

///|
/// Portable scale snapshot with original IDs and indices into report intervals.
pub fn snapshot_json(
  analysis : Analysis,
  scale : Double,
) -> Json raise TopologyError {
  let components = connected_components(analysis, scale)
  let cells_by_dimension = [0, 0, 0]
  for cell in analysis.filtration.cells {
    if cell.value <= scale {
      cells_by_dimension[cell.dimension] += 1
    }
  }
  let alive : Array[Int] = []
  for i = 0; i < analysis.intervals.length(); i = i + 1 {
    let interval = analysis.intervals[i]
    let survives = match interval.death {
      None => true
      Some(death) => scale < death
    }
    if interval.birth <= scale && survives {
      alive.push(i)
    }
  }
  {
    "schema_version": 1,
    "scale": scale,
    "cutoff": analysis.filtration.cutoff,
    "kind": analysis.filtration.kind,
    "h0": betti(analysis, 0, scale),
    "h1": betti(analysis, 1, scale),
    "active_cells_by_dimension": cells_by_dimension,
    "components": components,
    "alive_interval_indices": alive,
    "note": "component entries are input vertex IDs; interval indices refer to report.json; scale cannot exceed cutoff",
  }
}
