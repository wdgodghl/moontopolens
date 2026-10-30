///|
/// All public validation and computation errors carry an actionable message.
pub(all) suberror TopologyError {
  TopologyError(String)
} derive(@debug.Debug)

///|
pub fn TopologyError::message(self : TopologyError) -> String {
  match self {
    TopologyError(message) => message
  }
}

///|
/// A filtered cell. Boundary entries are indices of earlier cells.
pub struct Cell {
  key : String
  dimension : Int32
  value : Double
  boundary : Array[Int32]
  vertices : Array[Int32]
} derive(@debug.Debug)

///|
/// A finite filtration, ordered by value, dimension, then stable cell key.
pub struct Filtration {
  cells : Array[Cell]
  vertex_count : Int32
  kind : String
  cutoff : Double
  positions : Array[Array[Double]]
} derive(@debug.Debug)

///|
/// An interval [birth, death); None means alive at the filtration cutoff.
pub struct Interval {
  dimension : Int32
  birth : Double
  death : Double?
  birth_cell : Int32
  death_cell : Int32?
  representative : Array[Int32]
} derive(@debug.Debug)

///|
/// Reduction results retain the filtration so representatives can be decoded.
pub struct Analysis {
  filtration : Filtration
  intervals : Array[Interval]
  column_additions : Int32
  homology_dimension : Int32
  representatives_computed : Bool
  reduction_entries : Int32
} derive(@debug.Debug)

///|
pub extend TopologyError with @debug.Debug::{to_repr}

///|
pub extend Cell with @debug.Debug::{to_repr}

///|
pub extend Filtration with @debug.Debug::{to_repr}

///|
pub extend Interval with @debug.Debug::{to_repr}

///|
pub extend Analysis with @debug.Debug::{to_repr}

///|
priv struct RawCell {
  key : String
  dimension : Int32
  value : Double
  faces : Array[String]
  vertices : Array[Int32]
}

///|
fn finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}

///|
fn maximum(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn check_budget(size : Int32, limit : Int32) -> Unit raise TopologyError {
  if limit < 1 || limit > 10000 {
    raise TopologyError("max_cells must be between 1 and 10000")
  }
  if size > limit {
    raise TopologyError(
      "cell budget exceeded; lower threshold or reduce input size",
    )
  }
}

///|
fn vertex_key(v : Int32) -> String {
  "v:\{v}"
}

///|
fn edge_key(a : Int32, b : Int32) -> String {
  "e:\{a}:\{b}"
}

///|
fn triangle_key(a : Int32, b : Int32, c : Int32) -> String {
  "t:\{a}:\{b}:\{c}"
}

///|
fn tetrahedron_key(a : Int32, b : Int32, c : Int32, d : Int32) -> String {
  "q:\{a}:\{b}:\{c}:\{d}"
}

///|
fn finalize(
  raw : Array[RawCell],
  count : Int32,
  kind : String,
  cutoff : Double,
  positions~ : Array[Array[Double]] = [],
) -> Filtration raise TopologyError {
  raw.sort_by(fn(a, b) {
    if a.value < b.value {
      -1
    } else if a.value > b.value {
      1
    } else if a.dimension != b.dimension {
      a.dimension - b.dimension
    } else {
      a.key.compare(b.key)
    }
  })
  let index : Map[String, Int32] = Map([])
  let cells : Array[Cell] = []
  for cell in raw {
    if index.contains(cell.key) {
      raise TopologyError("duplicate cell key: " + cell.key)
    }
    let boundary : Array[Int32] = []
    for face in cell.faces {
      match index.get(face) {
        Some(i) => {
          if cells[i].dimension + 1 != cell.dimension {
            raise TopologyError("invalid face dimension")
          }
          boundary.push(i)
        }
        None => raise TopologyError("missing or later face: " + face)
      }
    }
    boundary.sort()
    index.set(cell.key, cells.length())
    cells.push({
      key: cell.key,
      dimension: cell.dimension,
      value: cell.value,
      boundary,
      vertices: cell.vertices.copy(),
    })
  }
  { cells, vertex_count: count, kind, cutoff, positions, }
}
