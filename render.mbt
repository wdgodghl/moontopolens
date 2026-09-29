///|
fn chart_bounds(analysis : Analysis) -> (Double, Double) {
  let mut low = 0.0
  let mut high = 1.0
  for cell in analysis.filtration.cells {
    if cell.value < low {
      low = cell.value
    }
    if cell.value > high {
      high = cell.value
    }
  }
  (low, high)
}

///|
fn color(dimension : Int) -> String {
  if dimension == 0 {
    "#38bdf8"
  } else {
    "#fb923c"
  }
}

///|
/// Standalone SVG barcode. Drawing is capped at 80 rows; JSON retains all bars.
/// Essential bars have a dashed ending, indicating the input cutoff.
pub fn barcode_svg(analysis : Analysis) -> String {
  let (low, high) = chart_bounds(analysis)
  let count = if analysis.intervals.length() > 80 {
    80
  } else {
    analysis.intervals.length()
  }
  let height = 120 + count * 22
  let mut svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 900 \{height}\" role=\"img\" aria-label=\"MoonTopoLens persistence barcode\"><rect width=\"900\" height=\"\{height}\" fill=\"#0f172a\"/><g font-family=\"sans-serif\" fill=\"#e2e8f0\"><text x=\"30\" y=\"30\" font-size=\"20\">MoonTopoLens | Persistence barcode</text><text x=\"30\" y=\"55\" font-size=\"12\">H0: components (blue) / H1: loops (orange) / dashed: alive at cutoff</text>"
  for tick = 0; tick <= 4; tick = tick + 1 {
    let x = 100 + tick * 185
    let value = low + (high - low) * tick.to_double() / 4.0
    svg += "<line x1=\"\{x}\" y1=\"75\" x2=\"\{x}\" y2=\"\{height - 30}\" stroke=\"#334155\"/><text x=\"\{x}\" y=\"\{height - 12}\" font-size=\"11\">\{value}</text>"
  }
  for i = 0; i < count; i = i + 1 {
    let interval = analysis.intervals[i]
    let x1 = 100.0 + (interval.birth - low) / (high - low) * 740.0
    let end = match interval.death {
      None => high
      Some(d) => d
    }
    let x2 = 100.0 + (end - low) / (high - low) * 740.0
    let y = 85 + i * 22
    let dash = if interval.death is None {
      " stroke-dasharray=\"7 4\""
    } else {
      ""
    }
    svg += "<text x=\"30\" y=\"\{y + 4}\" font-size=\"12\">H\{interval.dimension} #\{i}</text><line x1=\"\{x1}\" y1=\"\{y}\" x2=\"\{x2}\" y2=\"\{y}\" stroke=\"\{color(interval.dimension)}\" stroke-width=\"5\"\{dash}/><circle cx=\"\{x1}\" cy=\"\{y}\" r=\"3\" fill=\"\{color(interval.dimension)}\"/>"
  }
  if count < analysis.intervals.length() {
    svg += "<text x=\"30\" y=\"\{height - 35}\" font-size=\"11\">Showing first 80 intervals; full data is in report.json.</text>"
  }
  svg + "</g></svg>"
}

///|
/// Standalone birth/death scatter plot with essential classes shown at the top.
pub fn diagram_svg(analysis : Analysis) -> String {
  let (low, high) = chart_bounds(analysis)
  let mut svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 650 650\" role=\"img\" aria-label=\"MoonTopoLens persistence diagram\"><rect width=\"650\" height=\"650\" fill=\"#0f172a\"/><g font-family=\"sans-serif\" fill=\"#e2e8f0\"><text x=\"45\" y=\"30\" font-size=\"20\">MoonTopoLens | Persistence diagram</text><text x=\"45\" y=\"52\" font-size=\"12\">H0 blue / H1 orange / top row: alive at cutoff</text><path d=\"M 80 80 V 570 H 570 M 80 570 L 570 80\" fill=\"none\" stroke=\"#64748b\"/><text x=\"290\" y=\"625\">Birth</text><text x=\"10\" y=\"315\">Death</text>"
  for tick = 0; tick <= 4; tick = tick + 1 {
    let offset = tick.to_double() * 122.5
    let value = low + (high - low) * tick.to_double() / 4.0
    svg += "<text x=\"\{80.0 + offset}\" y=\"592\" font-size=\"10\">\{value}</text><text x=\"25\" y=\"\{570.0 - offset}\" font-size=\"10\">\{value}</text>"
  }
  for interval in analysis.intervals {
    let x = 80.0 + (interval.birth - low) / (high - low) * 490.0
    let y = match interval.death {
      None => 68.0
      Some(d) => 570.0 - (d - low) / (high - low) * 490.0
    }
    svg += "<circle cx=\"\{x}\" cy=\"\{y}\" r=\"4\" fill=\"\{color(interval.dimension)}\" opacity=\"0.8\"><title>H\{interval.dimension} birth=\{interval.birth}</title></circle>"
  }
  svg + "</g></svg>"
}
