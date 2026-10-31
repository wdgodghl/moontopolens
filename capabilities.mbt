// Generated from contracts/capabilities.json by scripts/sync-contracts.mjs.

///|
pub fn cli_help() -> String {
  "MoonTopoLens — 有界数据的拓扑计算、比较与解释\n数据入口：csv-preview / csv-points / csv-series / image / volume\n分析与解释：analyze / summary / slice / compare / landscape / shortest\n研究工作流：signal-csv / signal-study / reliability / cohort / pores\n其他命令与完整参数：\nreliability INPUT.json [--out NEW_DIRECTORY]\ncohort INPUT.json [--out NEW_DIRECTORY]\nsignal-study INPUT.json [--out NEW_DIRECTORY]\npores INPUT.json [--out NEW_DIRECTORY]\nsignal-csv INPUT.csv CONFIG.json [--out NEW_DIRECTORY]\npores-nifti INPUT.nii[.gz] CONFIG.json [--out NEW_DIRECTORY]\npore-compare LEFT_REQUEST.json RIGHT_REQUEST.json [--out NEW_DIRECTORY]\nshortest INPUT.json INTERVAL_INDEX [--out NEW_DIRECTORY]\ncsv-preview INPUT.csv [--columns X,Y]\npoints-sample INPUT.json SIZE [--out NEW_DIRECTORY]\ncsv-points INPUT.csv CUTOFF [--columns X,Y] [--normalize none|zscore|minmax] [--sample SIZE] [--out NEW_DIRECTORY]\ncsv-series INPUT.csv CUTOFF DIMENSION LAG STRIDE [--columns VALUE] [--normalize none|zscore|minmax] [--out NEW_DIRECTORY]\nanalyze INPUT.json [--intervals-only] [--out NEW_DIRECTORY]\nimage INPUT.pgm|INPUT.png CUTOFF|auto [--invert] [--out NEW_DIRECTORY]\nbatch MANIFEST.json --out NEW_DIRECTORY [--features DIMENSION START END]\nsequence FRAMES.json [--out NEW_DIRECTORY]\nvolume INPUT.nii|INPUT.nii.gz CUTOFF [--out NEW_DIRECTORY]\nvolume-sequence FRAMES.json|4D.nii[.gz] [CUTOFF] [--out NEW_DIRECTORY]\nvolume-coarse INPUT.json|INPUT.nii[.gz] [CUTOFF] [--out NEW_DIRECTORY]\nfield-stability IMAGE.pgm|IMAGE.png CUTOFF EPSILON [--out NEW_DIRECTORY]\nsweep SERIES_SWEEP.json [--out NEW_DIRECTORY]\nlag-hints SERIES_HINTS.json [--out NEW_DIRECTORY]\nstability POINTS.json EPSILON [--out NEW_DIRECTORY]\ncompare LEFT.json RIGHT.json [--out NEW_DIRECTORY]\nsummary INPUT.json\nrecommend INPUT.json [--out NEW_DIRECTORY]\nslice INPUT.json SCALE [--out NEW_DIRECTORY [--interval INDEX]]\nlandscape INPUT.json DIMENSION START END [--out NEW_DIRECTORY]\n使用 COMMAND --help 查看单个命令。输出目录必须尚不存在。"
}

///|
pub fn command_help(command : String) -> String? {
  match command {
    "reliability" =>
      Some(
        "reliability INPUT.json [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "cohort" =>
      Some(
        "cohort INPUT.json [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "signal-study" =>
      Some(
        "signal-study INPUT.json [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "pores" =>
      Some(
        "pores INPUT.json [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "signal-csv" =>
      Some(
        "signal-csv INPUT.csv CONFIG.json [--out NEW_DIRECTORY]\n默认 time,value 列，空 value 是缺失值；不规则采样必须显式配置 linear。\n示例：signal-csv examples/beijing-pm25/signal.csv examples/beijing-pm25/config.json --out out-signal\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "pores-nifti" =>
      Some(
        "pores-nifti INPUT.nii[.gz] CONFIG.json [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "pore-compare" =>
      Some(
        "pore-compare LEFT_REQUEST.json RIGHT_REQUEST.json [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "shortest" =>
      Some(
        "shortest INPUT.json INTERVAL_INDEX [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "csv-preview" =>
      Some(
        "csv-preview INPUT.csv [--columns X,Y]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "points-sample" =>
      Some(
        "points-sample INPUT.json SIZE [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "csv-points" =>
      Some(
        "csv-points INPUT.csv CUTOFF [--columns X,Y] [--normalize none|zscore|minmax] [--sample SIZE] [--out NEW_DIRECTORY]\n先用 csv-preview 检查表头；--columns x,y 显式选列。默认不归一化，归一化会改变尺度单位。\n示例：csv-points examples/iris/subset.csv 1.2 --columns petal_length_cm,petal_width_cm --out out-iris\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "csv-series" =>
      Some(
        "csv-series INPUT.csv CUTOFF DIMENSION LAG STRIDE [--columns VALUE] [--normalize none|zscore|minmax] [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "analyze" =>
      Some(
        "analyze INPUT.json [--intervals-only] [--out NEW_DIRECTORY]\n输入 kind：points / points_sparse / matrix / grid / volume / series。\n示例：analyze examples/square.json --out out-square\n失败：预算超限时调小截止尺度、显式采样或缩小数据；不会自动换成近似。\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "image" =>
      Some(
        "image INPUT.pgm|INPUT.png CUTOFF|auto [--invert] [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "batch" =>
      Some(
        "batch MANIFEST.json --out NEW_DIRECTORY [--features DIMENSION START END]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "sequence" =>
      Some(
        "sequence FRAMES.json [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "volume" =>
      Some(
        "volume INPUT.nii|INPUT.nii.gz CUTOFF [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "volume-sequence" =>
      Some(
        "volume-sequence FRAMES.json|4D.nii[.gz] [CUTOFF] [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "volume-coarse" =>
      Some(
        "volume-coarse INPUT.json|INPUT.nii[.gz] [CUTOFF] [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "field-stability" =>
      Some(
        "field-stability IMAGE.pgm|IMAGE.png CUTOFF EPSILON [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "sweep" =>
      Some(
        "sweep SERIES_SWEEP.json [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "lag-hints" =>
      Some(
        "lag-hints SERIES_HINTS.json [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "stability" =>
      Some(
        "stability POINTS.json EPSILON [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "compare" =>
      Some(
        "compare LEFT.json RIGHT.json [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "summary" =>
      Some(
        "summary INPUT.json\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "recommend" =>
      Some(
        "recommend INPUT.json [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "slice" =>
      Some(
        "slice INPUT.json SCALE [--out NEW_DIRECTORY [--interval INDEX]]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    "landscape" =>
      Some(
        "landscape INPUT.json DIMENSION START END [--out NEW_DIRECTORY]\nCLI 输入最大 1000000 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。",
      )
    _ => None
  }
}

///|
let boundary_dense_points : Int32 = 128

///|
let boundary_sparse_points : Int32 = 8192

///|
let boundary_point_dimensions : Int32 = 32

///|
let boundary_grid_axis : Int32 = 64

///|
let boundary_volume_axis : Int32 = 32

///|
let boundary_pore_axis : Int32 = 64

///|
let boundary_maximum_cells : Int32 = 10000

///|
let boundary_default_cells : Int32 = 4000

///|
pub fn project_version() -> String {
  "0.20.8"
}
