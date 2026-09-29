///|
fn group_color(index : Int) -> String {
  let palette = [
    "#38bdf8", "#a78bfa", "#34d399", "#f472b6", "#facc15", "#2dd4bf", "#e879f9",
  ]
  palette[index % palette.length()]
}

///|
/// Snapshot projection with MoonBit-computed component colors and an optional
/// live H1 birth representative. Requires coordinates; never invents matrix geometry.
pub fn scale_svg(
  analysis : Analysis,
  scale~ : Double,
  interval? : Int? = None,
) -> String raise TopologyError {
  let groups = connected_components(analysis, scale)
  let positions = analysis.filtration.positions
  if positions.is_empty() {
    raise TopologyError(
      "scale SVG requires display coordinates; matrix input has none",
    )
  }
  let highlighted : Map[Int, Bool] = Map([])
  if interval is Some(index) {
    if index < 0 || index >= analysis.intervals.length() {
      raise TopologyError("selected interval index is out of range")
    }
    let chosen = analysis.intervals[index]
    let alive = match chosen.death {
      None => true
      Some(death) => scale < death
    }
    if chosen.dimension != 1 || chosen.birth > scale || !alive {
      raise TopologyError(
        "selected interval must be an H1 class alive at the snapshot scale",
      )
    }
    ignore(cycle_edges(analysis, chosen))
    for cell in chosen.representative {
      highlighted[cell] = true
    }
  }
  let colors : Map[Int, String] = Map([])
  for i = 0; i < groups.length(); i = i + 1 {
    for vertex in groups[i] {
      colors[vertex] = group_color(i)
    }
  }
  let mut min_x = positions[0][0]
  let mut max_x = min_x
  let mut min_y = positions[0][1]
  let mut max_y = min_y
  for point in positions {
    if point[0] < min_x {
      min_x = point[0]
    }
    if point[0] > max_x {
      max_x = point[0]
    }
    if point[1] < min_y {
      min_y = point[1]
    }
    if point[1] > max_y {
      max_y = point[1]
    }
  }
  let raw_span = maximum(max_x - min_x, max_y - min_y)
  let span = if raw_span > 0.0 { raw_span } else { 1.0 }
  let xy = positions.map(fn(point) {
    (
      400.0 + 400.0 * ((point[0] - min_x) / span - (max_x - min_x) / span / 2.0),
      335.0 - 400.0 * ((point[1] - min_y) / span - (max_y - min_y) / span / 2.0),
    )
  })
  let mut svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 800 600\" role=\"img\" aria-label=\"MoonTopoLens scale snapshot\"><rect width=\"800\" height=\"600\" fill=\"#0f172a\"/><g font-family=\"sans-serif\" fill=\"#e2e8f0\"><text x=\"24\" y=\"32\" font-size=\"20\">MoonTopoLens | Scale snapshot</text><text x=\"24\" y=\"58\" font-size=\"14\">scale=\{scale} | H0=\{groups.length()} | H1=\{betti(analysis, 1, scale)}</text><text x=\"24\" y=\"80\" font-size=\"12\">Vertex colors: components (palette repeats after 7); orange edges: selected H1 birth chain</text>"
  for i = 0; i < analysis.filtration.cells.length(); i = i + 1 {
    let cell = analysis.filtration.cells[i]
    if cell.value > scale || cell.dimension != 1 {
      continue
    }
    let a = xy[cell.vertices[0]]
    let b = xy[cell.vertices[1]]
    let selected = highlighted.contains(i)
    let stroke = if selected { "#fb923c" } else { "#64748b" }
    let width = if selected { 4 } else { 1 }
    svg += "<line x1=\"\{a.0}\" y1=\"\{a.1}\" x2=\"\{b.0}\" y2=\"\{b.1}\" stroke=\"\{stroke}\" stroke-width=\"\{width}\"/>"
  }
  for cell in analysis.filtration.cells {
    if cell.value > scale || cell.dimension != 0 {
      continue
    }
    let vertex = cell.vertices[0]
    let p = xy[vertex]
    let fill = colors[vertex]
    svg += "<circle cx=\"\{p.0}\" cy=\"\{p.1}\" r=\"6\" fill=\"\{fill}\"><title>input vertex \{vertex}</title></circle><text x=\"\{p.0 + 8.0}\" y=\"\{p.1 - 8.0}\" font-size=\"11\">\{vertex}</text>"
  }
  svg +
  "<text x=\"24\" y=\"580\" font-size=\"12\">Display projection only; 2D fillings not drawn; birth chains are not guaranteed shortest.</text></g></svg>"
}
