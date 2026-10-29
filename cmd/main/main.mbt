///|
fn usage() -> Unit {
  println("MoonTopoLens — persistent H0/H1/H2 analysis")
  println("shortest INPUT.json INTERVAL_INDEX [--out NEW_DIRECTORY]")
  println(
    "Exact large points: analyze a kind=points_sparse request; CSV: --engine sparse --max-cells 10000",
  )
  println(
    "moon run --target js cmd/main -- csv-preview INPUT.csv [--columns X,Y]",
  )
  println(
    "moon run --target js cmd/main -- points-sample INPUT.json SIZE [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- csv-points INPUT.csv CUTOFF [--columns X,Y] [--normalize none|zscore|minmax] [--sample SIZE] [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- csv-series INPUT.csv CUTOFF DIMENSION LAG STRIDE [--columns VALUE] [--normalize none|zscore|minmax] [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- analyze INPUT.json [--intervals-only] [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- image INPUT.pgm|INPUT.png CUTOFF|auto [--invert] [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- batch MANIFEST.json --out NEW_DIRECTORY [--features DIMENSION START END]",
  )
  println(
    "moon run --target js cmd/main -- sequence FRAMES.json [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- volume INPUT.nii|INPUT.nii.gz CUTOFF [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- volume-sequence FRAMES.json|4D.nii[.gz] [CUTOFF] [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- volume-coarse INPUT.json|INPUT.nii[.gz] [CUTOFF] [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- field-stability GRID_OR_VOLUME.json EPSILON [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- field-stability IMAGE.pgm|IMAGE.png CUTOFF EPSILON [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- sweep SERIES_SWEEP.json [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- lag-hints SERIES_HINTS.json [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- stability POINTS.json EPSILON [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- compare LEFT.json RIGHT.json [--out NEW_DIRECTORY]",
  )
  println("moon run --target js cmd/main -- summary INPUT.json")
  println(
    "moon run --target js cmd/main -- recommend INPUT.json [--out NEW_DIRECTORY]",
  )
  println(
    "moon run --target js cmd/main -- slice INPUT.json SCALE [--out NEW_DIRECTORY [--interval INDEX]]",
  )
  println(
    "moon run --target js cmd/main -- landscape INPUT.json DIMENSION START END [--out NEW_DIRECTORY]",
  )
  println(
    "Request kinds: points / matrix / grid / volume / series. See examples and README.",
  )
}

///|
fn load(
  path : String,
  representatives? : Bool = true,
) -> @topo.Analysis raise @topo.TopologyError {
  let text = read_input(path)
  if text == "" {
    raise @topo.TopologyError(
      "input missing, unreadable, empty or exceeds 1MB: " + path,
    )
  }
  @topo.analyze_json(text, representatives~)
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
fn csv_integer_argument(index : Int) -> Int raise @topo.TopologyError {
  let value = numeric_argument(index)
  if value < 1.0 || value > 10000.0 || value != @math.floor(value) {
    raise @topo.TopologyError(
      "CSV embedding arguments must be integers in 1..10000",
    )
  }
  value.to_int()
}

///|
fn save_analysis(
  output : String,
  result : @topo.Analysis,
  report : String,
  source? : Json = Json::null(),
) -> Bool raise @topo.TopologyError {
  save_output(output, "report.json", report) &&
  save_output(output, "barcode.svg", @topo.barcode_svg(result)) &&
  save_output(output, "diagram.svg", @topo.diagram_svg(result)) &&
  save_output(output, "intervals.csv", @topo.intervals_csv(result)) &&
  save_output(output, "betti.csv", @topo.betti_csv(result)) &&
  save_output(output, "betti-events.csv", @topo.betti_events_csv(result)) &&
  save_output(
    output,
    "recommendations.json",
    @topo.recommendations_json(result).stringify(),
  ) &&
  save_output(output, "recommendations.csv", @topo.recommendations_csv(result)) &&
  save_output(output, "report.html", @topo.html_report(result, source~)) &&
  (
    result.filtration.kind != "cubical_volume" ||
    !result.representatives_computed ||
    (
      save_output(
        output,
        "volume-slices.html",
        @topo.volume_slices_html(result),
      ) &&
      save_output(
        output,
        "volume-surfaces.json",
        @topo.volume_h2_surfaces_json(result).stringify(),
      )
    )
  )
}

///|
fn image_info(
  image : @topo.PgmImage,
  cutoff : Double,
  automatic : Bool,
  inverted : Bool,
  source_format? : String = "PGM",
) -> Json {
  {
    "source_format": source_format,
    "encoding": if source_format == "PNG" {
      "decoded_grayscale_8bit"
    } else {
      image.encoding
    },
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
      "csv-preview" => {
        if (count != 2 && count != 4) ||
          (count == 4 && argument(2) != "--columns") {
          raise @topo.TopologyError(
            "csv-preview requires INPUT.csv [--columns X,Y]",
          )
        }
        let columns : Array[String] = []
        if count == 4 {
          for name in argument(3).split(",") {
            columns.push(name.to_owned())
          }
        }
        println(
          @topo.csv_preview_json(
            @topo.parse_numeric_csv(read_input(argument(1)), columns~),
          ).stringify(),
        )
      }
      "csv-points" | "csv-series" => {
        let series = argument(0) == "csv-series"
        let required = if series { 6 } else { 3 }
        let columns : Array[String] = []
        let mut normalization = "none"
        let mut sample_size = 0
        let mut engine = "dense"
        let mut max_cells = 4000
        let mut output = ""
        let mut option = required
        let seen : Array[String] = []
        while option < count {
          let key = argument(option)
          if option + 1 >= count || seen.contains(key) {
            raise @topo.TopologyError(
              "CSV options require unique names and values",
            )
          }
          seen.push(key)
          match key {
            "--columns" =>
              for name in argument(option + 1).split(",") {
                columns.push(name.to_owned())
              }
            "--engine" => engine = argument(option + 1)
            "--max-cells" => max_cells = csv_integer_argument(option + 1)
            "--sample" => sample_size = csv_integer_argument(option + 1)
            "--normalize" => normalization = argument(option + 1)
            "--out" => {
              output = argument(option + 1)
              if output == "" {
                raise @topo.TopologyError("empty output path")
              }
            }
            _ => raise @topo.TopologyError("unknown CSV option")
          }
          option += 2
        }
        if count < required {
          raise @topo.TopologyError("missing CSV analysis arguments")
        }
        if engine != "dense" && engine != "sparse" {
          raise @topo.TopologyError("engine must be dense or sparse")
        }
        if series && engine != "dense" {
          raise @topo.TopologyError(
            "sparse engine currently requires CSV points",
          )
        }
        let source = read_input(argument(1))
        let request = @topo.csv_request_json(
          source,
          if series {
            "series"
          } else if engine == "sparse" {
            "points_sparse"
          } else {
            "points"
          },
          threshold=numeric_argument(2),
          dimension=if series { csv_integer_argument(3) } else { 2 },
          lag=if series { csv_integer_argument(4) } else { 1 },
          stride=if series { csv_integer_argument(5) } else { 1 },
          columns~,
          normalization~,
          sample_size~,
          max_cells~,
        )
        let result = @topo.analyze_json(request.stringify())
        let info = if series {
          @topo.csv_series_preparation_json(
            source,
            columns~,
            normalization~,
            dimension=csv_integer_argument(3),
            lag=csv_integer_argument(4),
            stride=csv_integer_argument(5),
          )
        } else {
          @topo.csv_preparation_json(
            source,
            columns~,
            normalization~,
            sample_size~,
          )
        }
        let sampling = match info {
          Object(fields) =>
            match fields.get("sampling") {
              Some(value) => value
              None => Json::null()
            }
          _ => Json::null()
        }
        let metadata : Json = {
          "csv": info,
          "sampling": sampling,
          "engine": engine,
          "approximate": match sampling {
            Object(fields) =>
              match fields.get("approximate") {
                Some(value) => value
                None => false.to_json()
              }
            _ => false.to_json()
          },
        }
        let report = @topo.report_json(result, source=metadata).stringify()
        if output != "" {
          if !new_output(output) {
            raise @topo.TopologyError(
              "output directory must be new and have an existing parent",
            )
          }
          if !save_analysis(output, result, report, source=metadata) ||
            !save_output(output, "csv-request.json", request.stringify()) ||
            !save_output(output, "csv-info.json", info.stringify()) {
            raise @topo.TopologyError("could not save complete CSV analysis")
          }
        }
        println(report)
      }
      "points-sample" => {
        if (count != 3 && count != 5) ||
          (count == 5 && (argument(3) != "--out" || argument(4) == "")) {
          raise @topo.TopologyError(
            "points-sample requires INPUT.json SIZE [--out NEW_DIRECTORY]",
          )
        }
        let (request, info) = @topo.sampled_points_request(
          read_input(argument(1)),
          size=csv_integer_argument(2),
        )
        let result = @topo.analyze_json(request.stringify())
        let metadata : Json = { "sampling": info }
        let report = @topo.report_json(result, source=metadata).stringify()
        if count == 5 {
          let output = argument(4)
          if !new_output(output) {
            raise @topo.TopologyError(
              "output directory must be new and have an existing parent",
            )
          }
          if !save_analysis(output, result, report, source=metadata) ||
            !save_output(output, "sample-request.json", request.stringify()) ||
            !save_output(output, "sampling-info.json", info.stringify()) {
            raise @topo.TopologyError("could not save sampled analysis")
          }
        }
        println(report)
      }
      "shortest" => {
        if (count != 3 && count != 5) ||
          (count == 5 && (argument(3) != "--out" || argument(4) == "")) {
          raise @topo.TopologyError(
            "shortest requires INPUT.json INTERVAL_INDEX [--out NEW_DIRECTORY]",
          )
        }
        let value = numeric_argument(2)
        if value < 0.0 || value > 10000.0 || value != @math.floor(value) {
          raise @topo.TopologyError(
            "interval index must be an integer in 0..10000",
          )
        }
        let result = load(argument(1))
        let report = @topo.shortest_representative_json(result, value.to_int()).stringify()
        if count == 5 {
          if !new_output(argument(4)) ||
            !save_output(argument(4), "shortest.json", report) {
            raise @topo.TopologyError("could not save shortest representative")
          }
        }
        println(report)
      }
      "volume" => {
        if (count != 3 && count != 5) ||
          (count == 5 && (argument(3) != "--out" || argument(4) == "")) {
          print_error(
            "volume requires INPUT.nii|INPUT.nii.gz CUTOFF and optional --out NEW_DIRECTORY",
          )
          return
        }
        let path = argument(1).to_lower()
        if !path.has_suffix(".nii") && !path.has_suffix(".nii.gz") {
          raise @topo.TopologyError(
            "volume input must end with .nii or .nii.gz",
          )
        }
        let bytes = read_nifti_input(argument(1))
        if bytes.length() == 0 {
          raise @topo.TopologyError(
            "NIfTI input missing, invalid or exceeds 1 MB",
          )
        }
        let study = @topo.parse_nifti1_study(
          Array::makei(bytes.length(), fn(i) { bytes[i] }),
        )
        if study.volumes.length() != 1 {
          raise @topo.TopologyError("4D NIfTI requires volume-sequence command")
        }
        let cutoff = numeric_argument(2)
        let analysis = @topo.analyze(
          @topo.cubical_volume(study.volumes[0], threshold=cutoff),
          max_homology_dimension=2,
        )
        let report = @topo.report_json(analysis).stringify()
        if count == 5 {
          let output = argument(4)
          if !new_output(output) ||
            !save_analysis(output, analysis, report) ||
            !save_output(
              output,
              "nifti-info.json",
              @topo.nifti_study_metadata(study).stringify(),
            ) ||
            !save_output(
              output,
              "volume-surfaces-world.json",
              @topo.volume_h2_world_surfaces_json(analysis, study.affine).stringify(),
            ) {
            print_error("could not save NIfTI analysis")
            return
          }
        }
        println(report)
      }
      "volume-sequence" => {
        let path = argument(1).to_lower()
        let nifti = path.has_suffix(".nii") || path.has_suffix(".nii.gz")
        let basic = if nifti { 3 } else { 2 }
        if (count != basic && count != basic + 2) ||
          (
            count == basic + 2 &&
            (argument(basic) != "--out" || argument(basic + 1) == "")
          ) {
          print_error(
            "volume-sequence requires FRAMES.json or 4D.nii[.gz] CUTOFF and optional --out NEW_DIRECTORY",
          )
          return
        }
        let mut metadata : Json? = None
        let report = if nifti {
          let bytes = read_nifti_input(argument(1))
          if bytes.length() == 0 {
            raise @topo.TopologyError("4D NIfTI missing or exceeds 1 MB")
          }
          let study = @topo.parse_nifti1_study(
            Array::makei(bytes.length(), fn(i) { bytes[i] }),
          )
          if study.volumes.length() < 2 {
            raise @topo.TopologyError(
              "4D sequence requires at least two frames",
            )
          }
          metadata = Some(@topo.nifti_study_metadata(study))
          let frames : Array[Json] = []
          for index, volume in study.volumes {
            frames.push({ "name": "frame-\{index}", "volume": volume })
          }
          let request : Json = {
            "kind": "volume_sequence",
            "threshold": numeric_argument(2),
            "frames": frames,
          }
          @topo.volume_sequence_json(request.stringify())
        } else {
          let source = read_input(argument(1))
          if source == "" {
            raise @topo.TopologyError(
              "volume sequence input missing or exceeds 1 MB",
            )
          }
          @topo.volume_sequence_json(source)
        }
        let output_text = report.stringify()
        if count == basic + 2 {
          let output = argument(basic + 1)
          if !new_output(output) ||
            !save_output(output, "volume-sequence.json", output_text) ||
            !save_output(
              output,
              "volume-sequence.html",
              @topo.volume_sequence_html(report),
            ) ||
            (match metadata {
              Some(value) =>
                !save_output(output, "nifti-info.json", value.stringify())
              None => false
            }) {
            print_error("could not save volume sequence")
            return
          }
        }
        println(output_text)
      }
      "volume-coarse" => {
        let path = argument(1).to_lower()
        let nifti = path.has_suffix(".nii") || path.has_suffix(".nii.gz")
        let basic = if nifti { 3 } else { 2 }
        if (count != basic && count != basic + 2) ||
          (
            count == basic + 2 &&
            (argument(basic) != "--out" || argument(basic + 1) == "")
          ) {
          print_error(
            "volume-coarse requires JSON or NIfTI CUTOFF and optional --out NEW_DIRECTORY",
          )
          return
        }
        let mut metadata : Json? = None
        let (analysis, stride) = if nifti {
          let bytes = read_nifti_input(argument(1))
          if bytes.length() == 0 {
            raise @topo.TopologyError("NIfTI input missing or exceeds 1 MB")
          }
          let study = @topo.parse_nifti1_study(
            Array::makei(bytes.length(), fn(i) { bytes[i] }),
          )
          if study.volumes.length() != 1 {
            raise @topo.TopologyError("coarse volume requires one NIfTI frame")
          }
          metadata = Some(@topo.nifti_study_metadata(study))
          @topo.analyze_volume_coarse(
            study.volumes[0],
            threshold=numeric_argument(2),
          )
        } else {
          let source = read_input(argument(1))
          if source == "" {
            raise @topo.TopologyError(
              "coarse volume JSON missing or exceeds 1 MB",
            )
          }
          @topo.analyze_volume_coarse_json(source)
        }
        let info : Json = {
          "kind": "volume_coarse",
          "stride": stride,
          "approximate": stride > 1,
          "sampling": "local_mean",
          "interpretation": "topology is computed on the coarse grid; it is not the exact full-resolution persistence",
        }
        let report = @topo.report_json(analysis).stringify()
        if count == basic + 2 {
          let output = argument(basic + 1)
          if !new_output(output) ||
            !save_analysis(output, analysis, report) ||
            !save_output(output, "coarsening-info.json", info.stringify()) ||
            (match metadata {
              Some(value) =>
                !save_output(output, "nifti-info.json", value.stringify())
              None => false
            }) {
            print_error("could not save coarse volume")
            return
          }
        }
        println(info.stringify())
      }
      "field-stability" => {
        let image_path = argument(1).to_lower().has_suffix(".pgm") ||
          argument(1).to_lower().has_suffix(".png")
        let basic = if image_path { 4 } else { 3 }
        if (count != basic && count != basic + 2) ||
          (
            count == basic + 2 &&
            (argument(basic) != "--out" || argument(basic + 1) == "")
          ) {
          print_error(
            "field-stability requires JSON EPSILON or IMAGE CUTOFF EPSILON and optional --out NEW_DIRECTORY",
          )
          return
        }
        let source = if image_path {
          let bytes = read_binary_input(argument(1))
          if bytes.length() == 0 {
            raise @topo.TopologyError(
              "field stability image missing or exceeds 1 MB",
            )
          }
          let raster = if argument(1).to_lower().has_suffix(".png") {
            png_as_pgm(bytes)
          } else {
            bytes
          }
          if raster.length() == 0 {
            raise @topo.TopologyError("invalid or unsupported stability image")
          }
          let image = @topo.parse_pgm(
            Array::makei(raster.length(), fn(i) { raster[i] }),
          )
          (
            {
              "kind": "grid",
              "threshold": numeric_argument(2),
              "grid": image.grid,
            } : Json).stringify()
        } else {
          let value = read_input(argument(1))
          if value == "" {
            raise @topo.TopologyError(
              "field stability input missing or exceeds 1 MB",
            )
          }
          value
        }
        let report = @topo.field_stability_json(
          source,
          numeric_argument(if image_path { 3 } else { 2 }),
        )
        let output_text = report.stringify()
        if count == basic + 2 {
          let output = argument(basic + 1)
          if !new_output(output) ||
            !save_output(output, "field-stability.json", output_text) {
            print_error("could not save field stability")
            return
          }
        }
        println(output_text)
      }
      "sequence" => {
        if count != 2 && count != 4 {
          print_error(
            "sequence requires FRAMES.json and optional --out NEW_DIRECTORY",
          )
          return
        }
        if count == 4 && (argument(2) != "--out" || argument(3) == "") {
          print_error("expected --out NEW_DIRECTORY")
          return
        }
        let source = read_input(argument(1))
        if source == "" {
          raise @topo.TopologyError(
            "sequence input missing, unreadable, empty or exceeds 1MB",
          )
        }
        let (report, frames_csv, transitions_csv, tracks_csv) = @topo.topology_sequence(
          source,
        )
        let report_text = report.stringify()
        if count == 4 {
          let output = argument(3)
          if !new_output(output) ||
            !save_output(output, "sequence.json", report_text) ||
            !save_output(output, "frames.csv", frames_csv) ||
            !save_output(output, "transitions.csv", transitions_csv) ||
            !save_output(output, "tracks.csv", tracks_csv) ||
            !save_output(
              output,
              "sequence.html",
              @topo.topology_sequence_html(report),
            ) {
            print_error("could not save topology sequence")
            return
          }
        }
        println(report_text)
      }
      "lag-hints" => {
        if count != 2 && count != 4 {
          print_error(
            "lag-hints requires SERIES_HINTS.json and optional --out NEW_DIRECTORY",
          )
          return
        }
        if count == 4 && (argument(2) != "--out" || argument(3) == "") {
          print_error("expected --out NEW_DIRECTORY")
          return
        }
        let source = read_input(argument(1))
        if source == "" {
          raise @topo.TopologyError(
            "series hints input missing, unreadable, empty or exceeds 1MB",
          )
        }
        let (report, csv) = @topo.series_lag_hints(source)
        let report_text = report.stringify()
        if count == 4 {
          let output = argument(3)
          if !new_output(output) ||
            !save_output(output, "lag-hints.json", report_text) ||
            !save_output(output, "lag-hints.csv", csv) {
            print_error("could not save lag hints")
            return
          }
        }
        println(report_text)
      }
      "stability" => {
        if (count != 3 && count != 5) ||
          (count == 5 && (argument(3) != "--out" || argument(4) == "")) {
          print_error(
            "stability requires POINTS.json EPSILON and optional --out NEW_DIRECTORY",
          )
          return
        }
        let source = read_input(argument(1))
        if source == "" {
          raise @topo.TopologyError(
            "stability input missing, unreadable or exceeds 1MB",
          )
        }
        let report = @topo.point_stability_json(source, numeric_argument(2))
        let report_text = report.stringify()
        if count == 5 {
          let output = argument(4)
          if !new_output(output) ||
            !save_output(output, "stability.json", report_text) ||
            !save_output(
              output,
              "stability.html",
              @topo.point_stability_html(report),
            ) {
            print_error("could not save stability report")
            return
          }
        }
        println(report_text)
      }
      "sweep" => {
        if count != 2 && count != 4 {
          print_error(
            "sweep requires SERIES_SWEEP.json and optional --out NEW_DIRECTORY",
          )
          return
        }
        if count == 4 && (argument(2) != "--out" || argument(3) == "") {
          print_error("expected --out NEW_DIRECTORY")
          return
        }
        let source = read_input(argument(1))
        if source == "" {
          raise @topo.TopologyError(
            "sweep input missing, unreadable, empty or exceeds 1MB",
          )
        }
        let (report, summary_csv, vector_csv) = @topo.series_sweep(source)
        let report_text = report.stringify()
        if count == 4 {
          let output = argument(3)
          if !new_output(output) {
            print_error(
              "output directory must be new and have an existing parent: " +
              output,
            )
            return
          }
          if !save_output(output, "sweep.json", report_text) ||
            !save_output(output, "sweep-summary.csv", summary_csv) ||
            !save_output(output, "sweep-landscape.csv", vector_csv) ||
            !save_output(output, "sweep.html", @topo.series_sweep_html(report)) {
            print_error("could not save complete parameter sweep")
            return
          }
        }
        println(report_text)
      }
      "batch" => {
        if (count != 4 && count != 8) ||
          argument(2) != "--out" ||
          argument(3) == "" ||
          (count == 8 && argument(4) != "--features") {
          print_error(
            "batch requires MANIFEST.json --out NEW_DIRECTORY [--features DIMENSION START END]",
          )
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
            let raster = if case.format == "png" {
              png_as_pgm(bytes)
            } else {
              bytes
            }
            if raster.length() == 0 {
              raise @topo.TopologyError(
                "invalid or unsupported PNG image: " + case.input,
              )
            }
            let original = @topo.parse_pgm(
              Array::makei(raster.length(), fn(i) { raster[i] }),
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
              source_format=if case.format == "png" { "PNG" } else { "PGM" },
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
        let matrix = if plan.all_pairs {
          Some(@topo.batch_distance_matrix(plan, analyses))
        } else {
          None
        }
        let matrix_json = match matrix {
          Some(value) => @topo.batch_matrix_json(value).stringify()
          None => ""
        }
        let matrix_h0_csv = match matrix {
          Some(value) => @topo.batch_matrix_csv(value, 0)
          None => ""
        }
        let matrix_h1_csv = match matrix {
          Some(value) => @topo.batch_matrix_csv(value, 1)
          None => ""
        }
        let has_h2 = match matrix {
          Some(value) => value.h2_analyzed.contains(true)
          None => false
        }
        let matrix_h2_csv = match matrix {
          Some(value) => @topo.batch_matrix_csv(value, 2)
          None => ""
        }
        let matrix_html = match matrix {
          Some(value) => @topo.batch_matrix_html(value)
          None => ""
        }
        let cluster_h0 = match matrix {
          Some(value) => Some(@topo.batch_clustering(value, 0))
          None => None
        }
        let cluster_h1 = match matrix {
          Some(value) => Some(@topo.batch_clustering(value, 1))
          None => None
        }
        let cluster_h2 = match matrix {
          Some(value) => Some(@topo.batch_clustering(value, 2))
          None => None
        }
        let features = if count == 8 {
          let value = numeric_argument(5)
          if value < 0.0 || value > 2.0 || value != @math.floor(value) {
            raise @topo.TopologyError("feature dimension must be 0, 1 or 2")
          }
          Some(
            @topo.batch_features(
              analyses,
              plan.cases.map(fn(case) { case.name }),
              dimension=value.to_int(),
              start=numeric_argument(6),
              end=numeric_argument(7),
            ),
          )
        } else {
          None
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
              case.format != "json" &&
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
        if plan.all_pairs &&
          (
            !save_output(output, "distance-matrix.json", matrix_json) ||
            !save_output(output, "distance-h0.csv", matrix_h0_csv) ||
            !save_output(output, "distance-h1.csv", matrix_h1_csv) ||
            (has_h2 && !save_output(output, "distance-h2.csv", matrix_h2_csv)) ||
            !save_output(output, "distance-heatmap.html", matrix_html) ||
            !save_output(
              output,
              "cluster-h0.json",
              @topo.batch_clustering_json(cluster_h0.unwrap()).stringify(),
            ) ||
            !save_output(
              output,
              "cluster-h1.json",
              @topo.batch_clustering_json(cluster_h1.unwrap()).stringify(),
            ) ||
            !save_output(
              output,
              "cluster-h0.csv",
              @topo.batch_clustering_csv(cluster_h0.unwrap()),
            ) ||
            !save_output(
              output,
              "cluster-h1.csv",
              @topo.batch_clustering_csv(cluster_h1.unwrap()),
            ) ||
            !save_output(
              output,
              "cluster-h0.svg",
              @topo.batch_clustering_svg(cluster_h0.unwrap()),
            ) ||
            !save_output(
              output,
              "cluster-h1.svg",
              @topo.batch_clustering_svg(cluster_h1.unwrap()),
            ) ||
            (
              has_h2 &&
              (
                !save_output(
                  output,
                  "cluster-h2.json",
                  @topo.batch_clustering_json(cluster_h2.unwrap()).stringify(),
                ) ||
                !save_output(
                  output,
                  "cluster-h2.csv",
                  @topo.batch_clustering_csv(cluster_h2.unwrap()),
                ) ||
                !save_output(
                  output,
                  "cluster-h2.svg",
                  @topo.batch_clustering_svg(cluster_h2.unwrap()),
                )
              )
            )
          ) {
          print_error("could not save complete batch distance matrix")
          return
        }
        match features {
          Some((info, csv)) =>
            if !save_output(output, "features.json", info.stringify()) ||
              !save_output(output, "features.csv", csv) {
              raise @topo.TopologyError("could not save batch features")
            }
          None => ()
        }
        let summary : Json = {
          "features": if count == 8 {
            "features.json".to_json()
          } else {
            Json::null()
          },
          "case_count": plan.cases.length(),
          "comparison_count": plan.comparisons.length(),
          "total_cells": total_cells,
          "cases": case_summaries,
          "comparisons": pair_summaries,
          "all_pairs": plan.all_pairs,
          "distance_matrix": if plan.all_pairs {
            "distance-matrix.json".to_json()
          } else {
            Json::null()
          },
          "clustering_h0": if plan.all_pairs {
            "cluster-h0.json".to_json()
          } else {
            Json::null()
          },
          "clustering_h1": if plan.all_pairs {
            "cluster-h1.json".to_json()
          } else {
            Json::null()
          },
          "clustering_h2": if has_h2 {
            "cluster-h2.json".to_json()
          } else {
            Json::null()
          },
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
            "image requires INPUT.pgm|INPUT.png CUTOFF|auto [--invert] [--out NEW_DIRECTORY]",
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
            "image input missing, unreadable, empty or exceeds 1MB",
          )
        }
        let png = argument(1).to_lower().has_suffix(".png")
        let raster = if png { png_as_pgm(bytes) } else { bytes }
        if raster.length() == 0 {
          raise @topo.TopologyError("invalid or unsupported PNG image")
        }
        let original = @topo.parse_pgm(
          Array::makei(raster.length(), fn(i) { raster[i] }),
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
          let info = image_info(
            image,
            cutoff,
            automatic,
            inverted,
            source_format=if png { "PNG" } else { "PGM" },
          )
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
          let svg = if (
              result.filtration.positions.is_empty() ||
              result.filtration.kind == "cubical_volume"
            ) &&
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
          "2" => 2
          _ =>
            raise @topo.TopologyError("landscape dimension must be 0, 1 or 2")
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
      "recommend" => {
        if count != 2 && count != 4 {
          print_error(
            "recommend requires INPUT.json and optional --out NEW_DIRECTORY",
          )
          return
        }
        if count == 4 && (argument(2) != "--out" || argument(3) == "") {
          print_error("expected --out NEW_DIRECTORY")
          return
        }
        let result = load(argument(1))
        let report = @topo.recommendations_json(result).stringify()
        let csv = @topo.recommendations_csv(result)
        if count == 4 {
          let output = argument(3)
          if !new_output(output) {
            print_error(
              "output directory must be new and have an existing parent: " +
              output,
            )
            return
          }
          if !save_output(output, "recommendations.json", report) ||
            !save_output(output, "recommendations.csv", csv) {
            print_error("could not save complete recommendations")
            return
          }
        }
        println(report)
      }
      "analyze" => {
        let intervals_only = argument(2) == "--intervals-only"
        let base = if intervals_only { 3 } else { 2 }
        if count != base && count != base + 2 {
          print_error(
            "analyze requires INPUT.json, optional --intervals-only then --out NEW_DIRECTORY",
          )
          return
        }
        if count == base + 2 &&
          (argument(base) != "--out" || argument(base + 1) == "") {
          print_error("expected --out NEW_DIRECTORY")
          return
        }
        let result = load(argument(1), representatives=!intervals_only)
        let report = @topo.report_json(result).stringify()
        if count == base + 2 {
          let output = argument(base + 1)
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
