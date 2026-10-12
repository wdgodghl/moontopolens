///|
/// A numeric CSV table with a mandatory unique header. No missing values,
/// implicit column selection, normalization or resampling is performed.
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
pub fn parse_numeric_csv(text : String) -> NumericCsv raise TopologyError {
  if text.length() == 0 || text.length() > 1000000 {
    raise TopologyError("CSV input must contain 1..1000000 characters")
  }
  let headers : Array[String] = []
  let rows : Array[Array[Double]] = []
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
      continue
    }
    if fields.length() != headers.length() {
      raise TopologyError(
        "CSV row \{line_index + 1}: inconsistent column count",
      )
    }
    let values : Array[Double] = []
    for col, field in fields {
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
) -> Json raise TopologyError {
  let table = parse_numeric_csv(text)
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
