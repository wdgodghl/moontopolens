///|
fn usage() -> Unit {
  println("MoonTopoLens — persistent H0/H1 analysis")
  println(
    "moon run --target js cmd/main -- analyze INPUT.json [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- image INPUT.pgm CUTOFF|auto [--invert] [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- batch MANIFEST.json --out NEW_DIRECTORY",
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
fn save_analysis(
  output : String,
  result : @topo.Analysis,
  report : String,
) -> Bool raise @topo.TopologyError {
  save_output(output, "report.json", report) &&
  save_output(output, "barcode.svg", @topo.barcode_svg(result)) &&
  save_output(output, "diagram.svg", @topo.diagram_svg(result)) &&
  save_output(output, "intervals.csv", @topo.intervals_csv(result)) &&
  save_output(output, "betti.csv", @topo.betti_csv(result)) &&
  save_output(output, "betti-events.csv", @topo.betti_events_csv(result)) &&
  save_output(output, "report.html", @topo.html_report(result))
}

///|
fn image_info(
  image : @topo.PgmImage,
  cutoff : Double,
  automatic : Bool,
  inverted : Bool,
) -> Json {
  {
    "source_format": "PGM",
    "encoding": image.encoding,
    "width": image.grid[0].length(),
    "height": image.grid.length(),
    "max_value": image.max_value,
    "cutoff": cutoff,
    "cutoff_mode": if automatic {
      "auto_otsu"
    } else {
      "manual"
    },
    "inverted": inverted,
    "pixel_meaning": if inverted {
      "max_value minus raw grayscale; lower-star threshold uses transformed values"
    } else {
      "raw grayscale values without normalization; lower-star threshold uses the original values"
    },
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
      "batch" => {
        if count != 4 || argument(2) != "--out" || argument(3) == "" {
          print_error("batch requires MANIFEST.json --out NEW_DIRECTORY")
          return
        }
        let manifest = argument(1)
        let source = read_input(manifest)
        if source == "" {
          raise @topo.TopologyError(
            "batch manifest missing, unreadable or exceeds 1MB",
          )
        }
        let plan = @topo.parse_batch_manifest(source)
        let analyses : Array[@topo.Analysis] = []
        let reports : Array[String] = []
        let image_infos : Array[String] = []
        let positions : Map[String, Int] = Map([])
        let mut total_cells = 0
        for case in plan.cases {
          let result = if case.format == "json" {
            let input = read_batch_text(manifest, case.input)
            if input == "" {
              raise @topo.TopologyError(
                "batch input unreadable or outside manifest directory: " +
                case.input,
              )
            }
            image_infos.push("")
            @topo.analyze_json(input)
          } else {
            let bytes = read_batch_binary(manifest, case.input)
            if bytes.length() == 0 {
              raise @topo.TopologyError(
                "batch PGM unreadable or outside manifest directory: " +
                case.input,
              )
            }
            let original = @topo.parse_pgm(
              Array::makei(bytes.length(), fn(i) { bytes[i] }),
            )
            let image = if case.invert {
              @topo.invert_pgm(original)
            } else {
              original
            }
            let cutoff = if case.auto_threshold {
              @topo.otsu_threshold(image)
            } else {
              case.threshold.unwrap()
            }
            let info = image_info(
              image,
              cutoff,
              case.auto_threshold,
              case.invert,
            )
            image_infos.push(info.stringify())
            @topo.analyze(@topo.cubical_grid(image.grid, threshold=cutoff))
          }
          total_cells += result.filtration.cells.length()
          if total_cells > 16000 {
            raise @topo.TopologyError(
              "batch exceeds 16000 total filtration cells",
            )
          }
          positions[case.name] = analyses.length()
          analyses.push(result)
          reports.push(@topo.report_json(result).stringify())
        }
        let comparison_reports : Array[String] = []
        let comparison_csvs : Array[String] = []
        let comparison_htmls : Array[String] = []
        for pair in plan.comparisons {
          let left = analyses[positions[pair.left]]
          let right = analyses[positions[pair.right]]
          comparison_reports.push(
            @topo.comparison_json(left, right).stringify(),
          )
          comparison_csvs.push(@topo.matching_csv(left, right))
          comparison_htmls.push(@topo.comparison_html(left, right))
        }
        let output = argument(3)
        if !new_output(output) {
          print_error(
            "output directory must be new and have an existing parent: " +
            output,
          )
          return
        }
        let cases_dir = output + "/cases"
        let comparisons_dir = output + "/comparisons"
        if !new_output(cases_dir) || !new_output(comparisons_dir) {
          print_error("could not create batch output directories")
          return
        }
        let case_summaries : Array[Json] = []
        for index, case in plan.cases {
          let case_dir = cases_dir + "/" + case.name
          if !new_output(case_dir) ||
            !save_analysis(case_dir, analyses[index], reports[index]) ||
            (
              case.format == "pgm" &&
              !save_output(case_dir, "image-info.json", image_infos[index])
            ) {
            print_error("could not save complete batch case: " + case.name)
            return
          }
          case_summaries.push({
            "name": case.name,
            "input": case.input,
            "format": case.format,
            "report": "cases/" + case.name + "/report.json",
            "summary": @topo.summary_json(analyses[index]),
          })
        }
        let pair_summaries : Array[Json] = []
        for index, pair in plan.comparisons {
          let pair_dir = comparisons_dir + "/" + pair.name
          let left = analyses[positions[pair.left]]
          let right = analyses[positions[pair.right]]
          if !new_output(pair_dir) ||
            !save_output(pair_dir, "comparison.json", comparison_reports[index]) ||
            !save_output(pair_dir, "matches.csv", comparison_csvs[index]) ||
            !save_output(pair_dir, "comparison.html", comparison_htmls[index]) ||
            !save_output(pair_dir, "left-diagram.svg", @topo.diagram_svg(left)) ||
            !save_output(
              pair_dir,
              "right-diagram.svg",
              @topo.diagram_svg(right),
            ) {
            print_error(
              "could not save complete batch comparison: " + pair.name,
            )
            return
          }
          pair_summaries.push({
            "name": pair.name,
            "left": pair.left,
            "right": pair.right,
            "report": "comparisons/" + pair.name + "/comparison.json",
          })
        }
        let summary : Json = {
          "case_count": plan.cases.length(),
          "comparison_count": plan.comparisons.length(),
          "total_cells": total_cells,
          "cases": case_summaries,
          "comparisons": pair_summaries,
        }
        let output_text = summary.stringify()
        if !save_output(output, "batch.json", output_text) {
          print_error("could not save batch index")
          return
        }
        println(output_text)
      }
      "image" => {
        if count < 3 || count > 6 {
          print_error(
            "image requires INPUT.pgm CUTOFF|auto [--invert] [--out NEW_DIRECTORY]",
          )
          return
        }
        let inverted = count >= 4 && argument(3) == "--invert"
        let out_index = if inverted { 4 } else { 3 }
        let has_output = count == out_index + 2
        if !(count == out_index || has_output) ||
          (
            has_output &&
            (argument(out_index) != "--out" || argument(out_index + 1) == "")
          ) {
          print_error(
            "expected optional --invert followed by --out NEW_DIRECTORY",
          )
          return
        }
        let bytes = read_binary_input(argument(1))
        if bytes.length() == 0 {
          raise @topo.TopologyError(
            "PGM input missing, unreadable, empty or exceeds 1MB",
          )
        }
        let original = @topo.parse_pgm(
          Array::makei(bytes.length(), fn(i) { bytes[i] }),
        )
        let image = if inverted { @topo.invert_pgm(original) } else { original }
        let automatic = argument(2) == "auto"
        let cutoff = if automatic {
          @topo.otsu_threshold(image)
        } else {
          numeric_argument(2)
        }
        let result = @topo.analyze(
          @topo.cubical_grid(image.grid, threshold=cutoff),
        )
        let report = @topo.report_json(result).stringify()
        if has_output {
          let output = argument(out_index + 1)
          let info = image_info(image, cutoff, automatic, inverted)
          if !new_output(output) {
            print_error(
              "output directory must be new and have an existing parent: " +
              output,
            )
            return
          }
          if !save_analysis(output, result, report) ||
            !save_output(output, "image-info.json", info.stringify()) {
            print_error("could not save complete image report")
            return
          }
        }
        println(report)
      }
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
          if !save_analysis(output, result, report) {
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
