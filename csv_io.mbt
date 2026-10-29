///|
/// A numeric CSV table with a mandatory unique header. No missing values,
/// implicit normalization or resampling is performed.
pub struct NumericCsv {
  headers : Array[String]
  rows : Array[Array[Double]]
} derive(@debug.Debug)

///|
pub extend NumericCsv with @debug.Debug::{to_repr}

///|
fn csv_fields(line : String, row : Int) -> Array[String] raise TopologyError {
  let fields : Array[String] = []
  let mut field = ""
  let mut quoted = false
  let mut closed = false
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if quoted {
      if c == '"' {
        if i + 1 < chars.length() && chars[i + 1] == '"' {
          field += "\""
          i += 1
        } else {
          quoted = false
          closed = true
        }
      } else {
        field += c.to_string()
      }
    } else if c == ',' {
      fields.push(field.trim().to_owned())
      field = ""
      closed = false
    } else if c == '"' && !closed && field.trim().to_owned() == "" {
      field = ""
      quoted = true
    } else if c == '"' || (closed && c != ' ' && c != '\t' && c != '\r') {
      raise TopologyError("CSV row \{row}: unexpected text or quote")
    } else {
      field += c.to_string()
    }
    if field.length() > 256 || fields.length() >= 32 {
      raise TopologyError(
        "CSV fields must be <=256 characters and columns <=32",
      )
    }
    i += 1
  }
  if quoted {
    raise TopologyError(
      "CSV row \{row}: unclosed quote; multiline fields unsupported",
    )
  }
  fields.push(field.trim().to_owned())
  fields
}

///|
/// Read comma-separated numeric data. Supports BOM, CRLF, quoted fields and
/// escaped quotes in headers; numeric cells use JSON decimal/exponent syntax.
pub fn parse_numeric_csv(
  text : String,
  columns? : Array[String] = [],
) -> NumericCsv raise TopologyError {
  if text.length() == 0 || text.length() > 1000000 {
    raise TopologyError("CSV input must contain 1..1000000 characters")
  }
  let headers : Array[String] = []
  let rows : Array[Array[Double]] = []
  let selected : Array[Int] = []
  let width : Ref[Int] = Ref(0)
  for line_index, raw in text.split("\n").to_array() {
    let line = if line_index == 0 {
      raw.to_owned().trim_start(chars="\uFEFF").to_owned()
    } else {
      raw.to_owned()
    }
    if line.trim().to_owned() == "" {
      continue
    }
    let fields = csv_fields(line, line_index + 1)
    if headers.length() == 0 {
      for field in fields {
        if field == "" || headers.contains(field) {
          raise TopologyError("CSV headers must be nonempty and unique")
        }
        headers.push(field)
      }
      width.val = headers.length()
      if columns.length() == 0 {
        for i = 0; i < headers.length(); i = i + 1 {
          selected.push(i)
        }
      } else {
        let names : Array[String] = []
        for name in columns {
          if names.contains(name) || !headers.contains(name) {
            raise TopologyError(
              "CSV selected columns must be unique existing names",
            )
          }
          names.push(name)
          for i, header in headers {
            if header == name {
              selected.push(i)
            }
          }
        }
        headers.clear()
        for name in names {
          headers.push(name)
        }
      }
      continue
    }
    if fields.length() != width.val {
      raise TopologyError(
        "CSV row \{line_index + 1}: inconsistent column count",
      )
    }
    let values : Array[Double] = []
    for col in selected {
      let field = fields[col]
      let value : Double = @json.from_json(@json.parse(field)) catch {
        _ =>
          raise TopologyError(
            "CSV row \{line_index + 1}, column \{col + 1}: expected decimal number",
          )
      }
      if !finite(value) || value.abs() > 1.0e100 {
        raise TopologyError(
          "CSV row \{line_index + 1}, column \{col + 1}: number out of range",
        )
      }
      values.push(value)
    }
    rows.push(values)
    if rows.length() > 10000 {
      raise TopologyError("CSV supports at most 10000 data rows")
    }
  }
  if rows.length() == 0 {
    raise TopologyError(
      "CSV requires a header and at least one numeric data row",
    )
  }
  { headers, rows, }
}

///|
pub fn csv_preview_json(table : NumericCsv) -> Json {
  {
    "schema_version": 1,
    "row_count": table.rows.length(),
    "column_count": table.headers.length(),
    "headers": table.headers,
    "preview_rows": Array::makei(minimum_int(5, table.rows.length()), fn(i) {
      table.rows[i]
    }),
    "normalization": "none",
  }
}

///|
/// Convert a CSV into an ordinary reproducible analysis request.
pub fn csv_request_json(
  text : String,
  kind : String,
  threshold~ : Double,
  dimension? : Int = 2,
  lag? : Int = 1,
  stride? : Int = 1,
  columns? : Array[String] = [],
  normalization? : String = "none",
  sample_size? : Int = 0,
  max_cells? : Int = 4000,
) -> Json raise TopologyError {
  let table = transform_numeric_csv(
    parse_numeric_csv(text, columns~),
    normalization~,
  )
  if !finite(threshold) || threshold < 0.0 || threshold > 1.0e100 {
    raise TopologyError("CSV Rips threshold must be finite and nonnegative")
  }
  check_budget(0, max_cells)
  if kind == "points" || kind == "points_sparse" {
    if kind == "points_sparse" && sample_size != 0 {
      raise TopologyError("choose exact sparse or sampling, not both")
    }
    let points = if sample_size == 0 {
      table.rows
    } else {
      sample_points(table.rows, size=sample_size).points
    }
    if kind == "points_sparse" {
      ignore(rips_sparse(points, threshold~, max_cells~))
    } else {
      ignore(distance_matrix(points))
    }
    {
      "kind": kind,
      "threshold": threshold,
      "points": points,
      "max_cells": max_cells,
    }
  } else if kind == "series" {
    if sample_size != 0 {
      raise TopologyError("sampling is supported for points only")
    }
    if table.headers.length() != 1 {
      raise TopologyError("CSV series requires exactly one value column")
    }
    let series = table.rows.map(fn(row) { row[0] })
    ignore(delay_embed(series, dimension~, lag~, stride~))
    {
      "kind": "series",
      "threshold": threshold,
      "series": series,
      "dimension": dimension,
      "lag": lag,
      "stride": stride,
      "max_cells": max_cells,
    }
  } else {
    raise TopologyError("CSV kind must be points or series")
  }
}

///|
/// Transform selected numeric columns explicitly. Constant columns become zero.
pub fn transform_numeric_csv(
  table : NumericCsv,
  normalization? : String = "none",
) -> NumericCsv raise TopologyError {
  let info = csv_transform_json(table, normalization~)
  let fields = match info {
    Object(fields) => fields
    _ => raise TopologyError("invalid transform")
  }
  let offsets : Array[Double] = @json.from_json(
    required_field(fields, "offsets"),
  ) catch {
    _ => raise TopologyError("invalid offsets")
  }
  let scales : Array[Double] = @json.from_json(required_field(fields, "scales")) catch {
    _ => raise TopologyError("invalid scales")
  }
  {
    headers: table.headers.copy(),
    rows: table.rows.map(fn(row) {
      Array::makei(row.length(), fn(c) { (row[c] - offsets[c]) / scales[c] })
    }),
  }
}

///|
/// Reproducible per-column affine transform; zscore uses population deviation.
pub fn csv_transform_json(
  table : NumericCsv,
  normalization? : String = "none",
) -> Json raise TopologyError {
  if normalization != "none" &&
    normalization != "zscore" &&
    normalization != "minmax" {
    raise TopologyError("normalization must be none, zscore or minmax")
  }
  if table.rows.length() == 0 ||
    table.rows.length() > 10000 ||
    table.headers.length() == 0 ||
    table.headers.length() > 32 {
    raise TopologyError(
      "numeric table requires 1..10000 rows and 1..32 columns",
    )
  }
  let names : Array[String] = []
  for name in table.headers {
    if name == "" || names.contains(name) {
      raise TopologyError("numeric table headers must be unique and nonempty")
    }
    names.push(name)
  }
  for row in table.rows {
    if row.length() != table.headers.length() {
      raise TopologyError("inconsistent numeric table")
    }
    for v in row {
      if !finite(v) || v.abs() > 1.0e100 {
        raise TopologyError("numeric table value out of range")
      }
    }
  }
  let offsets : Array[Double] = []
  let scales : Array[Double] = []
  let constants : Array[String] = []
  for c = 0; c < table.headers.length(); c = c + 1 {
    let mut low = table.rows[0][c]
    let mut high = low
    let mut mean = 0.0
    for row in table.rows {
      low = if row[c] < low { row[c] } else { low }
      high = maximum(high, row[c])
      mean += row[c] / table.rows.length().to_double()
    }
    let mut deviation = 0.0
    let root_count = table.rows.length().to_double().sqrt()
    for row in table.rows {
      let delta = row[c] - mean
      deviation = @math.hypot(deviation, delta / root_count)
    }
    let offset = if normalization == "zscore" {
      if high == low {
        low
      } else {
        mean
      }
    } else if normalization == "minmax" {
      low
    } else {
      0.0
    }
    let scale = if normalization == "zscore" {
      if high == low {
        0.0
      } else {
        deviation
      }
    } else if normalization == "minmax" {
      high - low
    } else {
      1.0
    }
    offsets.push(offset)
    scales.push(if scale == 0.0 { 1.0 } else { scale })
    if high == low {
      constants.push(table.headers[c])
    }
  }
  {
    "normalization": normalization,
    "headers": table.headers,
    "offsets": offsets,
    "scales": scales,
    "constant_columns": constants,
    "formula": "(value - offset) / scale",
    "variance_convention": "population",
    "data_row_indices": Array::makei(table.rows.length(), fn(i) { i }),
    "row_count": table.rows.length(),
    "column_count": table.headers.length(),
    "preview_rows": Array::makei(minimum_int(5, table.rows.length()), fn(i) {
      table.rows[i]
    }),
  }
}

///|
/// Metadata maps analyzed vertices to zero-based nonblank CSV data rows.
pub fn csv_preparation_json(
  text : String,
  columns? : Array[String] = [],
  normalization? : String = "none",
  sample_size? : Int = 0,
) -> Json raise TopologyError {
  let raw = parse_numeric_csv(text, columns~)
  let transformed = transform_numeric_csv(raw, normalization~)
  let indices = if sample_size == 0 {
    Array::makei(raw.rows.length(), fn(i) { i })
  } else {
    sample_points(transformed.rows, size=sample_size).source_indices
  }
  let fields = match csv_transform_json(raw, normalization~) {
    Object(fields) => fields
    _ => raise TopologyError("invalid preparation metadata")
  }
  fields.set("data_row_indices", indices.to_json())
  fields.set("selected_raw_rows", indices.map(fn(i) { raw.rows[i] }).to_json())
  fields.set(
    "sampling",
    if sample_size == 0 {
      Json::null()
    } else {
      point_sample_json(sample_points(transformed.rows, size=sample_size))
    },
  )
  fields.set(
    "index_meaning",
    "zero-based nonblank data row, excluding header".to_json(),
  )
  fields.to_json()
}

///|
/// Source windows for delay-embedded CSV signals, before numeric transforms.
pub fn csv_series_preparation_json(
  text : String,
  columns? : Array[String] = [],
  normalization? : String = "none",
  dimension? : Int = 2,
  lag? : Int = 1,
  stride? : Int = 1,
) -> Json raise TopologyError {
  let raw = parse_numeric_csv(text, columns~)
  if raw.headers.length() != 1 {
    raise TopologyError("CSV series requires exactly one value column")
  }
  let windows = delay_embed(
    raw.rows.map(fn(row) { row[0] }),
    dimension~,
    lag~,
    stride~,
  )
  let fields = match csv_transform_json(raw, normalization~) {
    Object(fields) => fields
    _ => raise TopologyError("invalid series metadata")
  }
  fields.set(
    "data_row_indices",
    Array::makei(windows.length(), fn(i) { i * stride }).to_json(),
  )
  fields.set(
    "window_data_row_indices",
    Array::makei(windows.length(), fn(i) {
      Array::makei(dimension, fn(c) { i * stride + c * lag })
    }).to_json(),
  )
  fields.set("selected_raw_rows", windows.to_json())
  fields.set(
    "index_meaning",
    "zero-based nonblank data row indices of each delay window".to_json(),
  )
  fields.to_json()
}
