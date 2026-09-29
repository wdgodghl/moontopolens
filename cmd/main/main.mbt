///|
fn usage() -> Unit {
  println("MoonTopoLens — persistent H0/H1 analysis")
  println(
    "moon run --target js cmd/main -- analyze INPUT.json [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- compare LEFT.json RIGHT.json [--out NEW_DIRECTORY]",
  )
  println("moon run --target js cmd/main -- summary INPUT.json")
  println(
    "moon run --target js cmd/main -- slice INPUT.json SCALE [--out NEW_DIRECTORY [--interval INDEX]]",
  )
  println(
    "moon run --target js cmd/main -- landscape INPUT.json DIMENSION START END [--out NEW_DIRECTORY]",
  )
  println(
    "Request kinds: points / matrix / grid / series. See examples and README.",
  )
}

///|
fn load(path : String) -> @topo.Analysis raise @topo.TopologyError {
  let text = read_input(path)
  if text == "" {
    raise @topo.TopologyError(
      "input missing, unreadable, empty or exceeds 1MB: " + path,
    )
  }
  @topo.analyze_json(text)
}

///|
fn numeric_argument(index : Int) -> Double raise @topo.TopologyError {
  let parsed = @json.parse(argument(index)) catch {
    _ => raise @topo.TopologyError("expected a numeric argument")
  }
  match parsed {
    Number(value, ..) => value
    _ => raise @topo.TopologyError("expected a numeric argument")
  }
}

///|
fn main {
  let count = argument_count()
  if count == 0 || argument(0) == "--help" {
    usage()
    return
  }
  try {
    match argument(0) {
      "slice" => {
        if count != 3 && count != 5 && count != 7 {
          print_error(
            "slice requires INPUT.json SCALE and optional --out NEW_DIRECTORY [--interval INDEX]",
          )
          return
        }
        if count >= 5 && (argument(3) != "--out" || argument(4) == "") {
          print_error("expected --out NEW_DIRECTORY")
          return
        }
        let interval = if count == 7 {
          if argument(5) != "--interval" {
            raise @topo.TopologyError("expected --interval INDEX")
          }
          let value = numeric_argument(6)
          if value < 0.0 ||
            value > 10000.0 ||
            value != value.to_int().to_double() {
            raise @topo.TopologyError(
              "interval index must be a nonnegative integer <= 10000",
            )
          }
          Some(value.to_int())
        } else {
          None
        }
        let result = load(argument(1))
        let scale = numeric_argument(2)
        let report = @topo.snapshot_json(result, scale).stringify()
        if count >= 5 {
          let svg = if result.filtration.positions.is_empty() &&
            interval is None {
            None
          } else {
            Some(@topo.scale_svg(result, scale~, interval~))
          }
          let output = argument(4)
          if !new_output(output) {
            print_error(
              "output directory must be new and have an existing parent: " +
              output,
            )
            return
          }
          if !save_output(output, "slice.json", report) {
            print_error("could not save snapshot")
            return
          }
          if svg is Some(svg) {
            if !save_output(output, "slice.svg", svg) {
              print_error("could not save snapshot SVG")
              return
            }
          }
        }
        println(report)
      }
      "landscape" => {
        if count != 5 && count != 7 {
          print_error(
            "landscape requires INPUT.json DIMENSION START END and optional --out NEW_DIRECTORY",
          )
          return
        }
        if count == 7 && (argument(5) != "--out" || argument(6) == "") {
          print_error("expected --out NEW_DIRECTORY")
          return
        }
        let dimension = match argument(2) {
          "0" => 0
          "1" => 1
          _ => raise @topo.TopologyError("landscape dimension must be 0 or 1")
        }
        let result = load(argument(1))
        let start = numeric_argument(3)
        let end = numeric_argument(4)
        let report = @topo.landscape_json(result, dimension~, start~, end~).stringify()
        let csv = @topo.landscape_csv(result, dimension~, start~, end~)
        if count == 7 {
          let output = argument(6)
          if !new_output(output) {
            print_error(
              "output directory must be new and have an existing parent: " +
              output,
            )
            return
          }
          if !save_output(output, "landscape.json", report) ||
            !save_output(output, "landscape.csv", csv) {
            print_error("could not save complete landscape export")
            return
          }
        }
        println(report)
      }
      "summary" => {
        if count != 2 {
          print_error("summary requires INPUT.json")
          return
        }
        let result = load(argument(1))
        let summary : Json = {
          "cutoff": result.filtration.cutoff,
          "kind": result.filtration.kind,
          "vertex_count": result.filtration.vertex_count,
          "cell_count": result.filtration.cells.length(),
          "summary": @topo.summary_json(result),
          "note": "observed lifetimes of alive classes are lower bounds; finite entropy excludes them",
        }
        println(summary.stringify())
      }
      "analyze" => {
        if count != 2 && count != 4 {
          print_error(
            "analyze requires INPUT.json and optional --out NEW_DIRECTORY",
          )
          return
        }
        if count == 4 && (argument(2) != "--out" || argument(3) == "") {
          print_error("expected --out NEW_DIRECTORY")
          return
        }
        let result = load(argument(1))
        let report = @topo.report_json(result).stringify()
        if count == 4 {
          let output = argument(3)
          if !new_output(output) {
            print_error(
              "output directory must be new and have an existing parent: " +
              output,
            )
            return
          }
          if !save_output(output, "report.json", report) ||
            !save_output(output, "barcode.svg", @topo.barcode_svg(result)) ||
            !save_output(output, "diagram.svg", @topo.diagram_svg(result)) ||
            !save_output(output, "intervals.csv", @topo.intervals_csv(result)) ||
            !save_output(output, "betti.csv", @topo.betti_csv(result)) ||
            !save_output(
              output,
              "betti-events.csv",
              @topo.betti_events_csv(result),
            ) ||
            !save_output(output, "report.html", @topo.html_report(result)) {
            print_error(
              "could not save complete report; check filesystem permissions",
            )
            return
          }
        }
        println(report)
      }
      "compare" => {
        if count != 3 && count != 5 {
          print_error(
            "compare requires LEFT.json RIGHT.json and optional --out NEW_DIRECTORY",
          )
          return
        }
        if count == 5 && (argument(3) != "--out" || argument(4) == "") {
          print_error("expected --out NEW_DIRECTORY")
          return
        }
        let a = load(argument(1))
        let b = load(argument(2))
        let report = @topo.comparison_json(a, b).stringify()
        if count == 5 {
          let output = argument(4)
          let csv = @topo.matching_csv(a, b)
          let html = @topo.comparison_html(a, b)
          if !new_output(output) {
            print_error(
              "output directory must be new and have an existing parent: " +
              output,
            )
            return
          }
          if !save_output(output, "comparison.json", report) ||
            !save_output(output, "matches.csv", csv) ||
            !save_output(output, "comparison.html", html) ||
            !save_output(output, "left-diagram.svg", @topo.diagram_svg(a)) ||
            !save_output(output, "right-diagram.svg", @topo.diagram_svg(b)) {
            print_error("could not save complete comparison report")
            return
          }
        }
        println(report)
      }
      _ => {
        print_error("unknown command")
        usage()
      }
    }
  } catch {
    error => print_error(error.message())
  }
}
