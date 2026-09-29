///|
/// Offline side-by-side diagrams and a filterable optimal matching table.
pub fn comparison_html(
  a : Analysis,
  b : Analysis,
) -> String raise TopologyError {
  let data = comparison_json(a, b)
    .stringify()
    .replace_all(old="<", new="\\u003c")
  let header =
    #|<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MoonTopoLens · 拓扑比较报告</title>
    #|<style>*{box-sizing:border-box}body{margin:0;background:#0b1120;color:#e2e8f0;font:15px/1.7 system-ui,sans-serif}main{max-width:1180px;margin:auto;padding:28px 20px}h1{font-size:30px;margin:0}h2{font-size:19px}.panel{background:#111c30;border:1px solid #26354f;border-radius:14px;padding:20px;margin:18px 0}.diagrams{display:grid;grid-template-columns:1fr 1fr;gap:18px}.diagrams svg{width:100%;height:auto}.muted,small{color:#94a3b8}.notice{padding:12px 16px;background:#17253b;border-left:3px solid #facc15}.controls{display:flex;gap:20px;flex-wrap:wrap}select{padding:6px;background:#17253b;color:#e2e8f0}table{border-collapse:collapse;width:100%;font-size:13px}th,td{text-align:left;padding:9px;border-bottom:1px solid #26354f}.scroll{overflow:auto;max-height:520px}@media(max-width:720px){.diagrams{grid-template-columns:1fr}}</style></head><body><main><header><h1>MoonTopoLens · 拓扑比较</h1><p class="muted">查看两份数据的区间差异、瓶颈距离与一种最优匹配。</p></header>
    #|<section class="panel"><h2>比较摘要</h2><p id="distances"></p><p id="cutoffs"></p><div class="notice" id="comparability"></div><p class="muted">匹配可能不唯一。对角线表示数学上忽略该区间的配对代价，不能据此证明真实对象出现或消失。截止时仍存活的区间数量不同，完整距离为无有限匹配。</p></section><div class="diagrams"><section class="panel"><h2>左侧持续图</h2>
  let middle =
    #|</section><section class="panel"><h2>右侧持续图</h2>
  let table =
    #|</section></div><section class="panel"><h2>区间匹配明细</h2><div class="controls"><label>维度 <select id="dimension"><option value="all">全部</option><option value="0">H0 分量</option><option value="1">H1 环路</option></select></label><label><input type="checkbox" id="diagonal-only">仅对角线或未匹配</label></div><p id="match-count" class="muted"></p><div class="scroll"><table><thead><tr><th>维度</th><th>左侧 #编号 [出生,死亡)</th><th>右侧 #编号 [出生,死亡)</th><th>类型</th><th>代价</th></tr></thead><tbody id="matches"></tbody></table></div><small>表格最多显示 200 行；完整匹配保留在 comparison.json 和 matches.csv。图上的顶行表示截止时仍存活的区间。左右图各自使用显示范围，距离由原始数值计算。</small></section><footer class="muted">全部拓扑计算与匹配由 MoonBit 完成。该页面无需联网。</footer><script id="comparison-data" type="application/json">
  let script =
    #|</script><script>'use strict';
    #|const DATA=JSON.parse(document.getElementById('comparison-data').textContent),el=id=>document.getElementById(id);
    #|const fmt=value=>value===null?'截止仍存活':String(Number(Number(value).toPrecision(6)));
    #|const label=interval=>interval===null?'对角线 / 无配对':`#${interval.index} [${fmt(interval.birth)}, ${fmt(interval.death)})`;
    #|const kinds={finite:'有限区间',diagonal:'对角线',censored:'截止仍存活',unmatched_censored:'未匹配存活类'};
    #|el('distances').textContent=DATA.distances.map(d=>`H${d.dimension} 瓶颈距离：${d.bottleneck===null?'无有限匹配':fmt(d.bottleneck)}`).join('；');
    #|el('cutoffs').textContent=`左侧截止：${fmt(DATA.left_cutoff)}；右侧截止：${fmt(DATA.right_cutoff)}`;
    #|el('comparability').textContent=DATA.cutoffs_equal&&DATA.complex_kinds_equal?'截止尺度和复形类型一致；请自行确认尺度单位及数据含义可比。':'截止尺度或复形类型不同；需确认截断条件和尺度单位，不能直接将数值差异解释为结构变化。';
    #|function render(){const dimension=el('dimension').value,diagonal=el('diagonal-only').checked,rows=DATA.distances.flatMap(d=>d.matches.map(m=>({...m,dimension:d.dimension}))).filter(m=>(dimension==='all'||String(m.dimension)===dimension)&&(!diagonal||m.kind==='diagonal'||m.kind==='unmatched_censored'));el('match-count').textContent=`共 ${rows.length} 个匹配，显示 ${Math.min(rows.length,200)} 行`;const body=el('matches');body.replaceChildren();for(const m of rows.slice(0,200)){const tr=document.createElement('tr');for(const value of [`H${m.dimension}`,label(m.left),label(m.right),kinds[m.kind],m.cost===null?'无有限匹配':fmt(m.cost)]){const td=document.createElement('td');td.textContent=value;tr.append(td);}body.append(tr);}}
    #|el('dimension').addEventListener('input',render);el('diagonal-only').addEventListener('input',render);render();</script></main></body></html>
  header + diagram_svg(a) + middle + diagram_svg(b) + table + data + script
}
