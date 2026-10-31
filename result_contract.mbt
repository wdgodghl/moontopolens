///|
/// Additive schema-1 envelope for public analysis, comparison and research reports.
fn result_envelope(report : Json) -> Json {
  let fields = match report {
    Object(f) => f.copy()
    _ => return report
  }
  let scope : Array[String] = []
  let states : Array[Json] = []
  if fields.contains("homology_dimension") && fields.contains("intervals") {
    let dimension : Int32 = @json.from_json(fields["homology_dimension"]) catch {
      _ => 0
    }
    let intervals : Array[Json] = @json.from_json(fields["intervals"]) catch {
      _ => []
    }
    let reps = fields.get("representatives_computed") == Some(Json(true))
    for d = 0; d < 3; d = d + 1 {
      let mut finite = 0
      let mut censored = 0
      for interval in intervals {
        if interval is Object(f) && f.get("dimension") == Some(Json(d)) {
          if f.get("death") == Some(Json::null()) {
            censored += 1
          } else {
            finite += 1
          }
        }
      }
      states.push({
        "dimension": d,
        "status": if d > dimension {
          "not_computed"
        } else if finite + censored == 0 {
          "empty"
        } else {
          "observed"
        },
        "finite_intervals": if d > dimension {
          Json::null()
        } else {
          Json(finite)
        },
        "alive_at_cutoff": if d > dimension {
          Json::null()
        } else {
          Json(censored)
        },
        "representatives": if !reps || d > dimension {
          "not_computed"
        } else {
          "computed"
        },
      })
    }
    scope.push(
      "只解释本次声明的输入、过滤规则和截止尺度；截止时仍存活不证明无限寿命，未计算不等于没有特征。",
    )
    scope.push(
      "精确计算针对当前输入；输入是否已被外部采样、粗化或变换，需要结合来源记录判断。",
    )
  }
  let kind = match fields.get("kind") {
    Some(String(s)) => s
    _ => "comparison"
  }
  let source = fields.get("source").unwrap_or(Json::null())
  let mut approximation = "not_declared"
  if source is Object(f) {
    for key in ["sampling", "coarsening"] {
      if f.get(key) is Some(Object(s)) &&
        s.get("approximate") == Some(Json(true)) {
        approximation = "declared_approximation"
      }
    }
  }
  if approximation == "declared_approximation" {
    scope.push(
      "本次明确使用近似输入；采样覆盖半径或粗化步长不构成持久图区间误差保证。",
    )
  }
  match kind {
    "reliability" =>
      if fields.get("mode") == Some(Json("mean_band")) {
        scope.push(
          "置信带只针对声明为 IID 独立采样的总体平均有限第一层景观，在固定 31 点网格同时解释；不覆盖单个区间或整条连续曲线。",
        )
      } else {
        scope.push(
          "这是经验敏感性试验；匹配重复率不是特征真实的概率，重采样分位包络不保证覆盖率。",
        )
      }
    "signal_study" => {
      scope.push(
        "分数表示相对基准时段的变化提示，不是确认异常、故障诊断或误报率保证；重叠窗口相关。",
      )
      scope.push(
        if fields.get("evaluation") == Some(Json::null()) {
          "未提供事件真值：不报告准确率；插值及未分析窗口需结合 provenance 和 invalid_windows 查看。"
        } else {
          "评价仅按已声明事件与窗口重叠规则计算；不能解释为逐点准确率或事件级检出率。"
        },
      )
    }
    "cohort" =>
      scope.push(
        "独立采样、配对关系与标签交换性需要研究设计支持；穷举检验不验证这些假设。尺度校正在完整联合零假设下解释，组内差异分数不表示因果贡献。",
      )
    "pores" =>
      scope.push(
        "这是体素中心阈值分割与六面邻接区域；体积和面积依赖标定单位。中心采样内切球不是连续全局最大球，净空连通不等于渗透率，裁剪外部未知。",
      )
    "pore_compare" =>
      scope.push(
        "只比较相同声明网格上的空间重叠，不执行配准；出现、消失、分裂、合并均是标签关系，不证明物理身份。",
      )
    _ =>
      if fields.contains("distances") {
        scope.push(
          "持久图距离可以计算，不表示数据具有领域可比性；须另核对单位、预处理与采样方案。空距离是 unavailable，不是零距离。",
        )
      }
  }
  scope.push(
    "输入结构可自动检查；测量单位、研究假设、配准真实性和领域结论未由程序证明。",
  )
  fields.set("schema_version", Json(1))
  fields.set(
    "generator",
    ({ "name": "MoonTopoLens", "version": project_version() } : Json),
  )
  fields.set(
    "result_contract",
    (
      {
        "dimensions": states,
        "approximation": approximation,
        "scope": scope,
        "measurement_units_verified": false,
        "study_design_verified": false,
        "registration_verified": false,
      } : Json),
  )
  Json(fields)
}

///|
fn scope_html(report : Json) -> String {
  let fields = match report {
    Object(f) => f
    _ => return ""
  }
  let contract = match fields.get("result_contract") {
    Some(Object(f)) => f
    _ => return ""
  }
  let scope : Array[String] = match contract.get("scope") {
    Some(v) => @json.from_json(v) catch { _ => [] }
    None => []
  }
  let mut text = "<section class=\"panel\" id=\"result-boundaries\" aria-labelledby=\"boundaries-title\"><h2 id=\"boundaries-title\">本次结果的适用范围</h2><ul>"
  for item in scope {
    text += "<li>" +
      item
      .replace_all(old="&", new="&amp;")
      .replace_all(old="<", new="&lt;")
      .replace_all(old=">", new="&gt;") +
      "</li>"
  }
  text += "</ul>"
  if contract.get("approximation") == Some(Json("declared_approximation")) {
    text += "<p><strong>本次使用显式近似输入。</strong></p>"
  }
  if contract.get("dimensions") is Some(Array(dims)) {
    text += "<p>维度状态："
    for dim in dims {
      if dim is Object(f) {
        let d = f.get("dimension").unwrap_or(Json::null()).stringify()
        let status = match f.get("status") {
          Some(String(s)) => s
          _ => "not_computed"
        }
        text += " H" +
          d +
          " " +
          (match status {
            "not_computed" => "未计算"
            "empty" => "已计算、无区间"
            _ => "已计算、有观察结果"
          }) +
          "；"
      }
    }
    text += "</p>"
  }
  text + "</section>"
}
