///|
fn study_html(report : Json, title : String) -> String {
  let data = report.stringify().replace_all(old="<", new="\\u003c")
  let head =
    #|<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MoonTopoLens · 研究报告</title>
    #|<style>*{box-sizing:border-box}body{margin:0;background:#0b1120;color:#e2e8f0;font:15px/1.6 system-ui,sans-serif}main{max-width:1120px;margin:auto;padding:30px 20px}h1{font-size:30px;margin:4px 0}h2{font-size:18px;margin:0 0 12px}.muted,small{color:#94a3b8}.tag{color:#7dd3fc;letter-spacing:.12em;font-size:12px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:12px;margin:20px 0}.card,.panel{background:#111c30;border:1px solid #26354f;border-radius:14px;padding:18px}.value{font-size:26px;font-weight:700;color:#7dd3fc}.panel{margin:16px 0}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;min-width:650px}th,td{text-align:left;padding:10px;border-bottom:1px solid #26354f}th{color:#94a3b8}.bar{height:9px;background:#243454;border-radius:8px;overflow:hidden;min-width:90px}.bar>span{display:block;height:100%;background:#38bdf8}.rank{border-left:3px solid #a78bfa;padding:8px 14px;margin:10px 0;background:#19233a}footer{margin:25px 0;color:#94a3b8}</style></head><body><main><div class="tag">MOONTOPO LENS / OFFLINE STUDY</div><h1>
  let middle =
    #|</h1><p class="muted" id="subtitle"></p><section class="grid" id="cards"></section><section class="panel"><h2 id="table-title"></h2><div class="scroll"><table><thead id="headers"></thead><tbody id="rows"></tbody></table></div></section><section class="panel"><h2>解释与建议</h2><div id="recommendations"></div><p class="muted" id="interpretation"></p></section><footer>由 MoonBit 核心计算生成。离线打开即可查看，详细数值见同目录 JSON 与 CSV。</footer></main><script id="data" type="application/json">
  let tail =
    #|</script><script>'use strict';
    #|const data=JSON.parse(document.getElementById('data').textContent),$=id=>document.getElementById(id);
    #|const fmt=value=>value===null?'不可比较':typeof value==='number'?String(Number(value.toPrecision(5))):String(value);
    #|function card(label,value){const box=document.createElement('div');box.className='card';const name=document.createElement('small');name.textContent=label;const number=document.createElement('div');number.className='value';number.textContent=fmt(value);box.append(name,number);$('cards').append(box);}
    #|function table(columns,items,barKey){const tr=document.createElement('tr');for(const [key,label] of columns){const th=document.createElement('th');th.textContent=label;tr.append(th);}$('headers').append(tr);const max=Math.max(1,...items.map(x=>Number(x[barKey])||0));for(const item of items){const row=document.createElement('tr');for(const [key] of columns){const cell=document.createElement('td');cell.textContent=fmt(item[key]);if(key===barKey){const bar=document.createElement('div');bar.className='bar';const fill=document.createElement('span');fill.style.width=`${Math.max(0,Math.min(100,(Number(item[key])||0)/max*100))}%`;bar.append(fill);cell.append(bar);}row.append(cell);}$('rows').append(row);}}
    #|if(data.kind==='series_sweep'){$('subtitle').textContent='时间序列嵌入参数扫描 · 有限 H1 寿命仅用于候选排序';card('参数组合',data.case_count);card('过滤细胞总数',data.total_cells);card('候选组合',data.recommended_parameters.length);$('table-title').textContent='参数与环路摘要';table([['dimension','维数'],['lag','滞后'],['point_count','点数'],['h1_finite_count','有限 H1 数'],['longest_finite_h1_lifetime','最长有限 H1 寿命'],['h1_alive_at_cutoff','截止仍存活 H1']],data.cases,'longest_finite_h1_lifetime');for(const item of data.recommended_parameters){const p=document.createElement('div');p.className='rank';p.textContent=`#${item.rank} · 维数 ${item.dimension} / 滞后 ${item.lag} · 最长有限 H1 寿命 ${fmt(item.longest_finite_h1_lifetime)}`;$('recommendations').append(p);}$('interpretation').textContent=data.recommendation_note;}
    #|else if(data.kind==='point_stability'){$('subtitle').textContent='固定小幅扰动下的拓扑敏感性试验';card('点数',data.point_count);card('扰动幅度 ε',data.epsilon);card('重复次数',data.trials);card('基准 H1 数',data.baseline_h1_count);$('table-title').textContent='各次扰动对比';table([['trial','序号'],['cell_count','细胞数'],['h0_bottleneck','H0 距离'],['h1_bottleneck','H1 距离'],['h1_at_cutoff','截止 H1']],data.cases,'h1_bottleneck');for(const item of data.features){const p=document.createElement('div');p.className='rank';p.textContent=`H1 #${item.interval_index} · ${item.retained_trials}/${item.trial_count} 次匹配保留 · 观察寿命 ${fmt(item.observed_lifetime)}`;$('recommendations').append(p);}$('interpretation').textContent=data.interpretation;}
    #|else if(data.kind==='topology_sequence'){$('subtitle').textContent='按输入顺序观察多帧点云的连接分量和环路';card('帧数',data.frame_count);card('H1 轨迹',data.track_count);card('过滤细胞总数',data.total_cells);card('共同截止尺度',data.threshold);$('table-title').textContent='逐帧拓扑摘要';table([['name','帧'],['point_count','点数'],['h0_at_cutoff','截止 H0'],['h1_at_cutoff','截止 H1'],['h1_finite_count','有限 H1'],['longest_h1_observed_lifetime','最长 H1 观察寿命']],data.frames,'longest_h1_observed_lifetime');for(const item of data.transitions){const p=document.createElement('div');p.className='rank';p.textContent=`${item.left_name} → ${item.right_name} · H0 距离 ${fmt(item.h0_bottleneck)} / H1 距离 ${fmt(item.h1_bottleneck)} · H1 延续 ${item.continued_h1}、出现 ${item.appeared_h1}、消失 ${item.disappeared_h1}`;$('recommendations').append(p);}for(const track of data.tracks){const p=document.createElement('div');p.className='rank';p.textContent=`H1 轨迹 #${track.track_id} · ${track.observations.map(o=>`${data.frames[o.frame].name} (寿命 ${fmt(o.observed_lifetime)}${o.censored?'，截止仍存活':''})`).join(' → ')}`;$('recommendations').append(p);}$('interpretation').textContent=data.interpretation;}
    #|</script></body></html>
  head + title + middle + data + tail
}

///|
pub fn series_sweep_html(report : Json) -> String {
  study_html(report, "时间序列参数扫描")
}

///|
pub fn point_stability_html(report : Json) -> String {
  study_html(report, "点云稳定性分析")
}

///|
pub fn topology_sequence_html(report : Json) -> String {
  study_html(report, "多帧拓扑变化追踪")
}
