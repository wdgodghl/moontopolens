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
) -> Json raise TopologyError {
  let table = transform_numeric_csv(
    parse_numeric_csv(text, columns~),
    normalization~,
  )
  if !finite(threshold) || threshold < 0.0 || threshold > 1.0e100 {
    raise TopologyError("CSV Rips threshold must be finite and nonnegative")
  }
  if kind == "points" {
    ignore(distance_matrix(table.rows))
    { "kind": "points", "threshold": threshold, "points": table.rows }
  } else if kind == "series" {
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
  if table.rows.length() == 0 || table.headers.length() == 0 {
    raise TopologyError("empty numeric table")
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
    let mut variance = 0.0
    for row in table.rows {
      let delta = row[c] - mean
      variance += delta * delta / table.rows.length().to_double()
    }
    let offset = if normalization == "zscore" {
      mean
    } else if normalization == "minmax" {
      low
    } else {
      0.0
    }
    let scale = if normalization == "zscore" {
      variance.sqrt()
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
