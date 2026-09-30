///|
/// Symmetric H0/H1 bottleneck distances for one bounded batch study.
/// None means no finite match because alive interval counts differ.
pub struct BatchDistanceMatrix {
  names : Array[String]
  kinds : Array[String]
  cutoffs : Array[Double]
  h0 : Array[Array[Double?]]
  h1 : Array[Array[Double?]]
  conditions_aligned : Array[Array[Bool]]
} derive(@debug.Debug)

///|
pub extend BatchDistanceMatrix with @debug.Debug::{to_repr}

///|
/// Compute every unordered pair once. Agreement on kind and cutoff is only
/// a necessary metadata check; scale units and data meaning remain user choices.
pub fn batch_distance_matrix(
  plan : BatchPlan,
  analyses : Array[Analysis],
) -> BatchDistanceMatrix raise TopologyError {
  let n = plan.cases.length()
  if n < 1 || n > 8 || analyses.length() != n {
    raise TopologyError(
      "batch matrix requires 1..8 matching cases and analyses",
    )
  }
  let seen : Map[String, Bool] = Map([])
  for case in plan.cases {
    batch_name(case.name)
    if seen.contains(case.name) {
      raise TopologyError("duplicate batch matrix case name: " + case.name)
    }
    seen[case.name] = true
  }
  let names = plan.cases.map(fn(case) { case.name })
  let kinds = analyses.map(fn(result) { result.filtration.kind })
  let cutoffs = analyses.map(fn(result) { result.filtration.cutoff })
  let h0 = Array::makei(n, fn(_) { Array::make(n, None) })
  let h1 = Array::makei(n, fn(_) { Array::make(n, None) })
  let conditions_aligned = Array::makei(n, fn(_) { Array::make(n, false) })
  for i = 0; i < n; i = i + 1 {
    h0[i][i] = Some(0.0)
    h1[i][i] = Some(0.0)
    conditions_aligned[i][i] = true
    for j = i + 1; j < n; j = j + 1 {
      let d0 = compare_analyses(analyses[i], analyses[j], dimension=0)
      let d1 = compare_analyses(analyses[i], analyses[j], dimension=1)
      h0[i][j] = d0
      h0[j][i] = d0
      h1[i][j] = d1
      h1[j][i] = d1
      let aligned = kinds[i] == kinds[j] && cutoffs[i] == cutoffs[j]
      conditions_aligned[i][j] = aligned
      conditions_aligned[j][i] = aligned
    }
  }
  { names, kinds, cutoffs, h0, h1, conditions_aligned, }
}

///|
fn matrix_value(value : Double?) -> Json {
  match value {
    Some(number) => number.to_json()
    None => Json::null()
  }
}

///|
/// Portable matrix schema; null is deliberately distinct from a zero distance.
pub fn batch_matrix_json(matrix : BatchDistanceMatrix) -> Json {
  let h0 : Array[Array[Json]] = []
  let h1 : Array[Array[Json]] = []
  for row in matrix.h0 {
    h0.push(row.map(matrix_value))
  }
  for row in matrix.h1 {
    h1.push(row.map(matrix_value))
  }
  {
    "schema_version": 1,
    "metric": "bottleneck",
    "names": matrix.names,
    "kinds": matrix.kinds,
    "cutoffs": matrix.cutoffs,
    "h0": h0,
    "h1": h1,
    "conditions_aligned": matrix.conditions_aligned,
    "null_meaning": "unequal counts of classes alive at cutoff; no finite match",
    "comparison_note": "matching kind and cutoff is necessary but not sufficient; verify units, grayscale transforms and data meaning before interpreting distances",
  }
}

///|
/// Square CSV with blanks for null distances. Batch names are CSV-safe ASCII.
pub fn batch_matrix_csv(
  matrix : BatchDistanceMatrix,
  dimension : Int,
) -> String raise TopologyError {
  if dimension != 0 && dimension != 1 {
    raise TopologyError("matrix dimension must be 0 or 1")
  }
  let rows = if dimension == 0 { matrix.h0 } else { matrix.h1 }
  let mut csv = "case"
  for name in matrix.names {
    csv += "," + name
  }
  csv += "\n"
  for i, name in matrix.names {
    csv += name
    for value in rows[i] {
      let field = match value {
        Some(number) => number.to_string()
        None => ""
      }
      csv += "," + field
    }
    csv += "\n"
  }
  csv
}

///|
fn matrix_max(rows : Array[Array[Double?]]) -> Double {
  let mut greatest = 0.0
  for row in rows {
    for value in row {
      if value is Some(number) && number > greatest {
        greatest = number
      }
    }
  }
  greatest
}

///|
fn matrix_table(
  matrix : BatchDistanceMatrix,
  rows : Array[Array[Double?]],
  dimension : Int,
) -> String {
  let greatest = matrix_max(rows)
  let mut html = "<section class=panel><h2>H\{dimension} 瓶颈距离</h2><div class=scroll><table><thead><tr><th>案例</th>"
  for name in matrix.names {
    html += "<th scope=col>\{name}</th>"
  }
  html += "</tr></thead><tbody>"
  for i, name in matrix.names {
    html += "<tr><th scope=row><a href=\"cases/\{name}/report.html\">\{name}</a></th>"
    for j = 0; j < matrix.names.length(); j = j + 1 {
      let warning = if matrix.conditions_aligned[i][j] {
        ""
      } else {
        " caution"
      }
      let content = match rows[i][j] {
        None =>
          "<span title=\"存活类数量不同，无有限匹配\">—</span>"
        Some(value) => {
          let opacity = if greatest == 0.0 {
            0.12
          } else {
            0.12 + 0.65 * value / greatest
          }
          "<span class=heat style=\"background:rgba(56,189,248,\{opacity})\">\{value}</span>"
        }
      }
      html += "<td class=\"cell\{warning}\">\{content}</td>"
    }
    html += "</tr>"
  }
  html + "</tbody></table></div></section>"
}

///|
fn matrix_html_escape(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
}

///|
/// Static offline heatmap with no JavaScript or network dependency.
pub fn batch_matrix_html(matrix : BatchDistanceMatrix) -> String {
  let mut html =
    #|<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MoonTopoLens · 批量距离热图</title><style>*{box-sizing:border-box}body{margin:0;background:#0b1120;color:#e2e8f0;font:15px/1.6 system-ui,sans-serif}main{max-width:1160px;margin:auto;padding:28px 20px}h1{margin:0;font-size:30px}h2{font-size:19px}.muted{color:#94a3b8}.panel{background:#111c30;border:1px solid #26354f;border-radius:14px;padding:20px;margin:18px 0}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;min-width:640px}th,td{padding:9px;text-align:center;border:1px solid #26354f}th:first-child{text-align:left}a{color:#93c5fd}.heat{display:block;border-radius:6px;padding:6px}.caution{outline:2px solid #f59e0b;outline-offset:-3px}.legend{border-left:3px solid #f59e0b;padding-left:12px}</style></head><body><main><h1>MoonTopoLens · 批量距离热图</h1><p class=muted>同一批案例的 H0/H1 瓶颈距离；每个无序案例对只计算一次。点击行标题查看案例报告。</p><section class=panel><h2>输入条件</h2><div class=scroll><table><thead><tr><th>案例</th><th>复形类型</th><th>截止值</th></tr></thead><tbody>
  for i, name in matrix.names {
    html += "<tr><th><a href=\"cases/\{name}/report.html\">\{name}</a></th><td>\{matrix_html_escape(matrix.kinds[i])}</td><td>\{matrix.cutoffs[i]}</td></tr>"
  }
  html += "</tbody></table></div><p class=legend>橙框表示两侧复形类型或截止值不同。相同类型和截止值也不保证尺度单位、灰度变换和数据含义可比。</p><p class=muted>破折号表示截止时存活类数量不同，因而没有有限匹配；它不是距离 0。颜色只按本维度的有限距离归一化，用于浏览，数值以 CSV/JSON 为准。</p></section>"
  html += matrix_table(matrix, matrix.h0, 0)
  html += matrix_table(matrix, matrix.h1, 1)
  html +
  "<footer class=muted>全部距离由 MoonBit 计算；页面可离线打开。</footer></main></body></html>"
}
