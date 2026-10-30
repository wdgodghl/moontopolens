///|
fn required_field(
  object : Map[String, Json],
  name : String,
) -> Json raise TopologyError {
  match object.get(name) {
    Some(value) => value
    None => raise TopologyError("missing field: " + name)
  }
}

///|
fn number_field(
  object : Map[String, Json],
  name : String,
) -> Double raise TopologyError {
  @json.from_json(required_field(object, name)) catch {
    _ => raise TopologyError(name + " must be a number")
  }
}

///|
fn integer_field(
  object : Map[String, Json],
  name : String,
  fallback : Int32,
) -> Int32 raise TopologyError {
  match object.get(name) {
    None => fallback
    Some(Number(n, ..)) => {
      if !finite(n) ||
        n != @math.floor(n) ||
        n < -2147483648.0 ||
        n > 2147483647.0 {
        raise TopologyError(name + " must be a 32-bit integer")
      }
      n.to_int()
    }
    Some(_) => raise TopologyError(name + " must be an integer")
  }
}

///|
fn rows_field(
  object : Map[String, Json],
  name : String,
) -> Array[Array[Double]] raise TopologyError {
  @json.from_json(required_field(object, name)) catch {
    _ => raise TopologyError(name + " must be an array of number arrays")
  }
}

///|
/// Parse a bounded JSON request, construct a filtration, then analyze it.
/// Supported kinds: points, matrix, grid, volume, series. Unknown fields are errors.
pub fn analyze_json(
  text : String,
  representatives~ : Bool = true,
) -> Analysis raise TopologyError {
  if text.length() > 1000000 {
    raise TopologyError("JSON request exceeds one million characters")
  }
  let value = @json.parse(text) catch {
    _ => raise TopologyError("invalid JSON request")
  }
  let object = match value {
    Object(fields) => fields
    _ => raise TopologyError("request must be a JSON object")
  }
  let kind : String = @json.from_json(required_field(object, "kind")) catch {
    _ => raise TopologyError("kind must be a string")
  }
  let threshold = number_field(object, "threshold")
  let budget = integer_field(object, "max_cells", 4000)
  let homology_dimension = integer_field(
    object,
    "homology_dimension",
    if kind == "volume" {
      2
    } else {
      1
    },
  )
  if homology_dimension != 1 && homology_dimension != 2 {
    raise TopologyError("homology_dimension must be 1 or 2")
  }
  if homology_dimension == 2 &&
    kind != "points" &&
    kind != "points_sparse" &&
    kind != "matrix" &&
    kind != "series" &&
    kind != "volume" {
    raise TopologyError(
      "H2 currently requires points, matrix, series or volume",
    )
  }
  if kind == "volume" && homology_dimension != 2 {
    raise TopologyError("volume requires homology_dimension 2")
  }
  let allowed = match kind {
    "points" | "points_sparse" =>
      ["kind", "threshold", "max_cells", "points", "homology_dimension"]
    "matrix" =>
      ["kind", "threshold", "max_cells", "matrix", "homology_dimension"]
    "grid" => ["kind", "threshold", "max_cells", "grid"]
    "volume" =>
      ["kind", "threshold", "max_cells", "volume", "homology_dimension"]
    "series" =>
      [
        "kind", "threshold", "max_cells", "series", "dimension", "lag", "stride",
        "homology_dimension",
      ]
    _ =>
      raise TopologyError(
        "unknown kind; expected points, matrix, grid, volume or series",
      )
  }
  allowed.push("representatives")
  let track = match object.get("representatives") {
    None => representatives
    Some(True) => representatives
    Some(False) => false
    _ => raise TopologyError("representatives must be a boolean")
  }
  for field in object.keys() {
    if !allowed.contains(field) {
      raise TopologyError("unknown field for " + kind + ": " + field)
    }
  }
  let filtration = match kind {
    "points_sparse" =>
      rips_sparse(
        rows_field(object, "points"),
        threshold~,
        max_cells=budget,
        max_dimension=homology_dimension + 1,
      )
    "points" =>
      rips(
        rows_field(object, "points"),
        threshold~,
        max_cells=budget,
        max_dimension=homology_dimension + 1,
      )
    "matrix" =>
      rips_matrix(
        rows_field(object, "matrix"),
        threshold~,
        max_cells=budget,
        max_dimension=homology_dimension + 1,
      )
    "grid" =>
      cubical_grid(rows_field(object, "grid"), threshold~, max_cells=budget)
    "volume" => {
      let volume : Array[Array[Array[Double]]] = @json.from_json(
        required_field(object, "volume"),
      ) catch {
        _ => raise TopologyError("volume must be an array of number matrices")
      }
      cubical_volume(volume, threshold~, max_cells=budget)
    }
    "series" => {
      let series : Array[Double] = @json.from_json(
        required_field(object, "series"),
      ) catch {
        _ => raise TopologyError("series must be an array of numbers")
      }
      let points = delay_embed(
        series,
        dimension=integer_field(object, "dimension", 2),
        lag=integer_field(object, "lag", 1),
        stride=integer_field(object, "stride", 1),
      )
      rips(
        points,
        threshold~,
        max_cells=budget,
        max_dimension=homology_dimension + 1,
      )
    }
    _ => raise TopologyError("unreachable kind")
  }
  analyze(
    filtration,
    max_homology_dimension=homology_dimension,
    representatives=track,
  )
}

///|
/// Portable report schema. null death means alive at the input cutoff.
/// Representative cell indices refer to the accompanying cells array.
pub fn report_json(analysis : Analysis, source~ : Json = Json::null()) -> Json {
  let intervals : Array[Json] = []
  for interval in analysis.intervals {
    let death : Json = match interval.death {
      None => Json::null()
      Some(value) => value.to_json()
    }
    let death_cell : Json = match interval.death_cell {
      None => Json::null()
      Some(value) => value.to_json()
    }
    intervals.push({
      "dimension": interval.dimension,
      "birth": interval.birth,
      "death": death,
      "birth_cell": interval.birth_cell,
      "death_cell": death_cell,
      "representative": interval.representative,
    })
  }
  let cells : Array[Json] = []
  for cell in analysis.filtration.cells {
    cells.push({
      "key": cell.key,
      "dimension": cell.dimension,
      "value": cell.value,
      "boundary": cell.boundary,
      "vertices": cell.vertices,
    })
  }
  let report : Json = {
    "schema_version": 1,
    "project": "MoonTopoLens",
    "coefficients": "GF(2)",
    "kind": analysis.filtration.kind,
    "cutoff": analysis.filtration.cutoff,
    "vertex_count": analysis.filtration.vertex_count,
    "cell_count": cells.length(),
    "column_additions": analysis.column_additions,
    "representatives_computed": analysis.representatives_computed,
    "reduction_entries": analysis.reduction_entries,
    "homology_dimension": analysis.homology_dimension,
    "positions": analysis.filtration.positions,
    "position_meaning": "point coordinates retained; 1D padded with zero; display uses first 2 or 3 coordinates; grid x and negative row; matrix has none",
    "summary": summary_json(analysis),
    "betti_events": betti_events_json(analysis),
    "essential_meaning": "alive at input cutoff; not proof of infinite lifetime",
    "representative_meaning": if analysis.representatives_computed {
      "cycle at birth; not guaranteed shortest"
    } else {
      "not computed; empty arrays do not mean absence of topology"
    },
    "intervals": intervals,
    "cells": cells,
  }
  if source != Json::null() {
    match report {
      Object(fields) => {
        fields.set("source", source)
        fields.to_json()
      }
      _ => report
    }
  } else {
    report
  }
}
