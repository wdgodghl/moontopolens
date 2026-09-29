/// All public validation and computation errors carry an actionable message.
pub suberror TopologyError {
  TopologyError(String)
} derive(@debug.Debug)

/// A filtered cell. Boundary entries are indices of earlier cells.
pub struct Cell {
  key : String
  dimension : Int
  value : Double
  boundary : Array[Int]
  vertices : Array[Int]
} derive(@debug.Debug)

/// A finite filtration, ordered by value, dimension, then stable cell key.
pub struct Filtration {
  cells : Array[Cell]
  vertex_count : Int
  kind : String
} derive(@debug.Debug)

/// An interval [birth, death); None means alive at the filtration cutoff.
pub struct Interval {
  dimension : Int
  birth : Double
  death : Double?
  birth_cell : Int
  death_cell : Int?
  representative : Array[Int]
} derive(@debug.Debug)

/// Reduction results retain the filtration so representatives can be decoded.
pub struct Analysis {
  filtration : Filtration
  intervals : Array[Interval]
  column_additions : Int
} derive(@debug.Debug)

pub extend TopologyError with @debug.Debug::{to_repr}
pub extend Cell with @debug.Debug::{to_repr}
pub extend Filtration with @debug.Debug::{to_repr}
pub extend Interval with @debug.Debug::{to_repr}
pub extend Analysis with @debug.Debug::{to_repr}

priv struct RawCell {
  key : String
  dimension : Int
  value : Double
  faces : Array[String]
  vertices : Array[Int]
}

fn finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}

fn maximum(a : Double, b : Double) -> Double {
  if a > b { a } else { b }
}

fn check_budget(size : Int, limit : Int) -> Unit raise TopologyError {
  if limit < 1 || limit > 10000 {
    raise TopologyError("max_cells must be between 1 and 10000")
  }
  if size > limit {
    raise TopologyError("cell budget exceeded; lower threshold or reduce input size")
  }
}

fn vertex_key(v : Int) -> String { "v:\{v}" }
fn edge_key(a : Int, b : Int) -> String { "e:\{a}:\{b}" }
fn triangle_key(a : Int, b : Int, c : Int) -> String { "t:\{a}:\{b}:\{c}" }

fn finalize(raw : Array[RawCell], count : Int, kind : String) -> Filtration raise TopologyError {
  raw.sort_by(fn(a, b) {
    if a.value < b.value { -1 } else if a.value > b.value { 1 }
    else if a.dimension != b.dimension { a.dimension - b.dimension }
    else { a.key.compare(b.key) }
  })
  let index : Map[String, Int] = Map([])
  let cells : Array[Cell] = []
  for cell in raw {
    if index.contains(cell.key) {
      raise TopologyError("duplicate cell key: " + cell.key)
    }
    let boundary : Array[Int] = []
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
    cells.push({ key: cell.key, dimension: cell.dimension, value: cell.value,
      boundary, vertices: cell.vertices.copy() })
  }
  { cells, vertex_count: count, kind }
}

