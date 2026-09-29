///|
fn usage() -> Unit {
  println("MoonTopoLens — persistent H0/H1 analysis")
  println(
    "moon run --target js cmd/main -- analyze INPUT.json [--out NEW_DIRECTORY]",
  )
  println("moon run --target js cmd/main -- compare LEFT.json RIGHT.json")
  println("moon run --target js cmd/main -- summary INPUT.json")
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
fn main {
  let count = argument_count()
  if count == 0 || argument(0) == "--help" {
    usage()
    return
  }
  try {
    match argument(0) {
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
        if count != 3 {
          print_error("compare requires LEFT.json RIGHT.json")
          return
        }
        let a = load(argument(1))
        let b = load(argument(2))
        let distances : Array[Json] = []
        for dimension = 0; dimension < 2; dimension = dimension + 1 {
          let distance = @topo.compare_analyses(a, b, dimension~)
          let d : Json = match distance {
            None => Json::null()
            Some(value) => value.to_json()
          }
          distances.push({
            "dimension": dimension,
            "bottleneck": d,
            "finite_distance": distance is Some(_),
          })
        }
        let report : Json = {
          "metric": "bottleneck",
          "distances": distances,
          "left_cutoff": a.filtration.cutoff,
          "right_cutoff": b.filtration.cutoff,
          "cutoffs_equal": a.filtration.cutoff == b.filtration.cutoff,
          "complex_kinds_equal": a.filtration.kind == b.filtration.kind,
          "note": "null means essential interval counts differ; use comparable cutoffs and units",
        }
        println(report.stringify())
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
