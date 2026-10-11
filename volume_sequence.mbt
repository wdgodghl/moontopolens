///|
fn volume_sequence_optional(value : Double?) -> Json {
  match value {
    Some(number) => number.to_json()
    None => Json::null()
  }
}

///|
fn volume_h2_observation(analysis : Analysis, frame : Int, index : Int) -> Json {
  let interval = analysis.intervals[index]
  {
    "frame": frame,
    "interval_index": index,
    "birth": interval.birth,
    "death": volume_sequence_optional(interval.death),
    "representative_face_count": interval.representative.length(),
  }
}

///|
/// Compare an ordered sequence of small 3D vertex-valued grids. H2 tracks
/// follow one optimal diagram matching and do not identify physical objects.
pub fn volume_sequence_json(text : String) -> Json raise TopologyError {
  if text.length() > 1000000 {
    raise TopologyError("volume sequence exceeds one million characters")
  }
  let parsed = @json.parse(text) catch {
    _ => raise TopologyError("invalid volume sequence JSON")
  }
  let root = batch_object(parsed, "volume sequence")
  batch_fields(
    root,
    ["kind", "threshold", "max_cells", "frames"],
    "volume sequence",
  )
  if batch_string(root, "kind") != "volume_sequence" {
    raise TopologyError("kind must be volume_sequence")
  }
  let threshold = number_field(root, "threshold")
  if !finite(threshold) || threshold.abs() > 1.0e100 {
    raise TopologyError("volume sequence threshold must be bounded and finite")
  }
  let budget = integer_field(root, "max_cells", 4000)
  check_budget(0, budget)
  let frame_values = batch_array(root, "frames", true)
  if frame_values.length() < 2 || frame_values.length() > 8 {
    raise TopologyError("volume sequence requires 2..8 frames")
  }
  let analyses : Array[Analysis] = []
  let names : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  let frames : Array[Json] = []
  let mut total_cells = 0
  let mut shape : Array[Int] = []
  for value in frame_values {
    let fields = batch_object(value, "volume frame")
    batch_fields(fields, ["name", "volume"], "volume frame")
    let name = batch_string(fields, "name")
    batch_name(name)
    if seen.contains(name) {
      raise TopologyError("duplicate volume frame name: " + name)
    }
    seen[name] = true
    let volume : Array[Array[Array[Double]]] = @json.from_json(
      required_field(fields, "volume"),
    ) catch {
      _ => raise TopologyError("volume frame must contain number matrices")
    }
    let analysis = analyze(
      cubical_volume(volume, threshold~, max_cells=budget),
      max_homology_dimension=2,
    )
    let current_shape = [
      volume.length(),
      volume[0].length(),
      volume[0][0].length(),
    ]
    if !shape.is_empty() && shape != current_shape {
      raise TopologyError("volume sequence frames must have the same shape")
    }
    shape = current_shape
    total_cells += analysis.filtration.cells.length()
    if total_cells > 24000 {
      raise TopologyError("volume sequence exceeds 24000 total cells")
    }
    frames.push({
      "index": frames.length(),
      "name": name,
      "cell_count": analysis.filtration.cells.length(),
      "h0_at_cutoff": betti(analysis, 0, threshold),
      "h1_at_cutoff": betti(analysis, 1, threshold),
      "h2_at_cutoff": betti(analysis, 2, threshold),
      "h2_intervals": analysis.intervals
      .filter(fn(i) { i.dimension == 2 })
      .length(),
    })
    analyses.push(analysis)
    names.push(name)
  }
  let tracks : Array[Array[Json]] = []
  let mut previous : Map[Int, Int] = Map([])
  for index, interval in analyses[0].intervals {
    if interval.dimension == 2 {
      let id = tracks.length()
      tracks.push([volume_h2_observation(analyses[0], 0, index)])
      previous[index] = id
    }
  }
  let transitions : Array[Json] = []
  for frame = 1; frame < analyses.length(); frame = frame + 1 {
    let left = analyses[frame - 1]
    let right = analyses[frame]
    let current : Map[Int, Int] = Map([])
    let mut continued = 0
    let mut appeared = 0
    let mut disappeared = 0
    for pair in interval_matching(left, right, dimension=2) {
      match (pair.left, pair.right) {
        (Some(a), Some(b)) => {
          let id = match previous.get(a) {
            Some(value) => value
            None => raise TopologyError("missing previous H2 track")
          }
          tracks[id].push(volume_h2_observation(right, frame, b))
          current[b] = id
          continued += 1
        }
        (None, Some(b)) => {
          let id = tracks.length()
          tracks.push([volume_h2_observation(right, frame, b)])
          current[b] = id
          appeared += 1
        }
        (Some(_), None) => disappeared += 1
        (None, None) => ()
      }
    }
    transitions.push({
      "left_frame": frame - 1,
      "right_frame": frame,
      "left_name": names[frame - 1],
      "right_name": names[frame],
      "h0_bottleneck": volume_sequence_optional(
        compare_analyses(left, right, dimension=0),
      ),
      "h1_bottleneck": volume_sequence_optional(
        compare_analyses(left, right, dimension=1),
      ),
      "h2_bottleneck": volume_sequence_optional(
        compare_analyses(left, right, dimension=2),
      ),
      "continued_h2": continued,
      "appeared_h2": appeared,
      "disappeared_h2": disappeared,
    })
    previous = current
  }
  let track_json : Array[Json] = []
  for id, observations in tracks {
    track_json.push({
      "track_id": id,
      "observation_count": observations.length(),
      "observations": observations,
    })
  }
  {
    "schema_version": 1,
    "kind": "volume_sequence",
    "threshold": threshold,
    "shape_zyx": shape,
    "frame_count": frames.length(),
    "total_cells": total_cells,
    "frames": frames,
    "transitions": transitions,
    "tracks": track_json,
    "interpretation": "H2 tracks are one optimal persistence-diagram correspondence; they do not prove physical cavity identity; null distance means incompatible cutoff-censored counts",
  }
}

///|
/// Offline timeline for precomputed volume-sequence summaries.
pub fn volume_sequence_html(report : Json) -> String {
  let data = report.stringify().replace_all(old="<", new="\\u003c")
  let start =
    #|<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MoonTopoLens · 三维变化</title><style>body{margin:0;background:#0b1120;color:#e2e8f0;font:15px/1.6 system-ui,sans-serif}main{max-width:1050px;margin:auto;padding:28px 20px}h1{font-size:30px}.muted{color:#94a3b8}.panel{background:#111c30;border:1px solid #26354f;border-radius:12px;padding:18px;margin:16px 0;overflow:auto}table{border-collapse:collapse;width:100%;min-width:650px}td,th{padding:9px;border-bottom:1px solid #334155;text-align:left}th{color:#7dd3fc}strong{color:#fbbf24}</style></head><body><main><h1>MoonTopoLens · 三维拓扑变化</h1><p class="muted">逐帧体数据在共同尺度下计算 H0/H1/H2。H2 区间数包含在截止前已消失的空腔；轨迹来自一种最优区间匹配，不能证明物理空腔身份。</p><section class="panel"><h2>逐帧摘要</h2><table id="frames"><thead><tr><th>帧</th><th>名称</th><th>细胞</th><th>H0 截止</th><th>H1 截止</th><th>H2 截止</th><th>H2 区间</th></tr></thead><tbody></tbody></table></section><section class="panel"><h2>相邻变化</h2><table id="transitions"><thead><tr><th>帧对</th><th>H2 瓶颈距离</th><th>延续</th><th>出现</th><th>消失</th></tr></thead><tbody></tbody></table></section><section class="panel"><h2>H2 区间轨迹</h2><table id="tracks"><thead><tr><th>轨迹</th><th>观察到的帧与区间</th></tr></thead><tbody></tbody></table></section></main><script id="data" type="application/json">
  let finish =
    #|</script><script>'use strict';const d=JSON.parse(document.getElementById('data').textContent),add=(table,values)=>{const row=document.createElement('tr');for(const value of values){const cell=document.createElement('td');cell.textContent=String(value);row.append(cell)}document.querySelector('#'+table+' tbody').append(row)},num=x=>x===null?'不可比较':Number(x).toPrecision(4);for(const f of d.frames)add('frames',[f.index,f.name,f.cell_count,f.h0_at_cutoff,f.h1_at_cutoff,f.h2_at_cutoff,f.h2_intervals]);for(const t of d.transitions)add('transitions',[`${t.left_name} → ${t.right_name}`,num(t.h2_bottleneck),t.continued_h2,t.appeared_h2,t.disappeared_h2]);for(const t of d.tracks)add('tracks',[t.track_id,t.observations.map(o=>`${d.frames[o.frame].name}: #${o.interval_index} [${o.birth}, ${o.death===null?'截止':o.death})`).join(' → ')]);</script></body></html>
  start + data + finish
}
