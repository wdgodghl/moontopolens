///|
/// A self-contained offline report. JavaScript only displays precomputed results:
/// slider filtering, table selection and coordinate projections; no homology runs in UI.
/// JSON escapes '<' so public cell keys cannot terminate the data script.
pub fn html_report(
  analysis : Analysis,
  source? : Json = Json::null(),
) -> String {
  let data = report_json(analysis, source~)
    .stringify()
    .replace_all(old="<", new="\\u003c")
  let header =
    #|<!doctype html>
    #|<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    #|<title>MoonTopoLens · 月拓镜分析报告</title>
    #|<style>
    #|[hidden]{display:none!important}*{box-sizing:border-box}body{margin:0;background:#0b1120;color:#e2e8f0;font:15px/1.6 system-ui,sans-serif}
    #|main{max-width:1180px;margin:auto;padding:30px 24px}h1{margin:0;font-size:32px}h2{font-size:18px;margin:0 0 12px}
    #|small,.muted{color:#94a3b8}header{margin-bottom:24px}.tag{display:inline-block;background:#123448;color:#7dd3fc;padding:3px 10px;border-radius:20px}
    #|.cards{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin:20px 0}.card,.panel{background:#111c30;border:1px solid #26354f;border-radius:14px;padding:18px}
    #|.value{font-size:28px;font-weight:650}.layout{display:grid;grid-template-columns:1.15fr 1fr;gap:18px}.controls{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin:12px 0}
    #|input[type=range]{width:100%;accent-color:#38bdf8}input[type=number]{width:100px}select,input,button{font:inherit;color:#e2e8f0;background:#16263e;border:1px solid #43526c;border-radius:7px;padding:6px}
    #|button{cursor:pointer}button:hover,button[aria-pressed=true]{border-color:#fb923c}svg{width:100%;background:#0b1426;border-radius:10px}table{width:100%;border-collapse:collapse;font-size:13px}th,td{text-align:left;padding:8px;border-bottom:1px solid #26354f}th{color:#94a3b8}tr.selected{background:#243454}
    #|.table-wrap{max-height:410px;overflow:auto}.blue{color:#38bdf8}.orange{color:#fb923c}.notice{border-left:3px solid #fb923c;padding:8px 14px;background:#192233;margin:16px 0}footer{margin-top:20px;color:#94a3b8;font-size:13px}
    #|.page-controls{display:flex;align-items:center;gap:12px;justify-content:flex-end;margin:12px 0}.page-controls button:disabled{opacity:.45;cursor:default}
    #|:focus-visible{outline:3px solid #38bdf8;outline-offset:3px}.page-controls{flex-wrap:wrap}.controls input[type=number]{max-width:100%}.table-wrap{overflow:auto}#scale-exact{width:160px}
    #|@media(max-width:850px){.layout{grid-template-columns:1fr}.cards{grid-template-columns:repeat(2,1fr)}}
    #|@media(max-width:480px){h1{font-size:26px;line-height:1.35}.panel,.card{padding:14px}main{padding:22px 16px}}
    #|</style></head><body><main>
    #|<header><span class="tag">OFFLINE REPORT / GF(2)</span><h1>MoonTopoLens <span class="muted">月拓镜</span></h1><p>观察尺度变化中的连接分量与闭合环路。此报告可离线打开，不会上传数据。</p><small id="meta"></small></header>
    #|<section class="cards" aria-label="拓扑摘要"><div class="card"><small>当前连接分量 H0</small><div class="value blue" id="h0"></div></div><div class="card"><small>当前环路 H1</small><div class="value orange" id="h1"></div></div><div class="card" id="h2-card" hidden><small>当前空腔 H2</small><div class="value" id="h2" style="color:#a78bfa"></div></div><div class="card"><small>细胞总数</small><div class="value" id="cells"></div></div><div class="card"><small>H1 最长有限寿命</small><div class="value" id="longest"></div></div></section>
    #|<section class="panel"><h2>选择观察尺度</h2><label for="scale">尺度 <output id="scale-value"></output></label><input id="scale" type="range" min="0" max="1000" value="1000"><small>统计采用 [出生,死亡) 区间；截止处仍存在的类不代表无限寿命。</small></section>
    #|<div class="controls"><label for="scale-exact">精确尺度</label><input id="scale-exact" type="number" step="any"><button id="event-previous" type="button">上一个事件</button><button id="event-next" type="button">下一个事件</button><output id="scale-message" aria-live="polite"></output></div>
    #|<div class="layout" style="margin-top:18px"><section class="panel"><h2>几何投影与代表环路</h2><p class="muted" id="projection-note"></p><div class="controls" id="rotation-controls" hidden><label>投影 <select id="projection-mode"><option value="xy">二维 XY</option><option value="3d">三维旋转</option></select></label><label>水平旋转 <input id="yaw" type="range" min="-180" max="180" value="0" aria-label="水平旋转角度"></label><label>俯仰 <input id="pitch" type="range" min="-90" max="90" value="0" aria-label="俯仰角度"></label><button id="rotation-reset" type="button">重置视角</button></div><svg id="geometry" viewBox="0 0 640 430" role="img" aria-label="过滤复形的坐标投影"></svg><small>灰线为当前进入的边，橙线为选中环路在出生时的代表；青绿色方格表示已进入的网格二维面。Rips 三角形未绘制。</small></section>
    #|<section class="panel"><h2>区间筛选与排名</h2><div class="controls"><label>维度 <select id="dimension"><option value="1">H1 环路</option><option value="0">H0 分量</option><option value="all">全部</option></select></label><label>最小观察寿命 <input id="minimum" type="number" min="0" value="0" step="any"></label><label><input id="alive-only" type="checkbox">仅当前存活</label></div><small id="table-count"></small><div class="table-wrap"><table><thead><tr><th>选择</th><th>维度</th><th>出生</th><th>死亡</th><th>观察寿命</th></tr></thead><tbody id="interval-table"></tbody></table></div><div class="page-controls"><button id="previous-page" type="button" aria-label="上一页">上一页</button><output id="page-status" aria-live="polite"></output><button id="next-page" type="button" aria-label="下一页">下一页</button></div><small>未死亡区间以截止尺度减出生尺度作为寿命下界。筛选结果可逐页查看，CSV 和 JSON 保留全部数据。</small></section></div>
    #|<section class="panel" style="margin-top:18px"><h2>Betti 曲线</h2><svg id="curve" viewBox="0 0 1000 250" role="img" aria-label="Betti 数随尺度变化的曲线"></svg><small>蓝色 H0 / 橙色 H1 / 紫色 H2（如已分析）；按全部出生和死亡事件绘制精确阶梯曲线。</small></section>
    #|<div class="notice">代表环路用于解释计算结果，不保证最短。三维视图使用前三个坐标，高维数据仍保留全部坐标参与计算；投影交叉不代表原空间相交。距离矩阵没有几何坐标时仍可查看全部拓扑结果。</div>
    #|<p id="selection-note" aria-live="polite">选择 H1 区间可查看出生时的代表环路；必要时自动切换到出生尺度。</p>
    #|<section class="panel" id="source-panel" hidden><h2>代表链对应的原始数据</h2><small id="source-meaning"></small><div class="table-wrap"><table><thead><tr><th>分析顶点</th><th>原始数据编号（从 0 开始）</th><th>原始数值 / 延迟窗口</th></tr></thead><tbody id="source-rows"></tbody></table></div></section>
    #|<p id="censor-note" class="notice"></p>
    #|<p id="source-note" class="notice" hidden></p>
    #|<footer>由 MoonBit 核心计算生成。配套文件：report.json、intervals.csv、betti.csv、betti-events.csv、barcode.svg、diagram.svg。</footer>
    #|</main><script id="topology-data" type="application/json">
  let script =
    #|</script><script>
    #|'use strict';
    #|const DATA=JSON.parse(document.getElementById('topology-data').textContent);
    #|const el=id=>document.getElementById(id), NS='http://www.w3.org/2000/svg';
    #|const sampling=DATA.source?.sampling; if(sampling){el('source-note').hidden=false;el('source-note').textContent=`${sampling.approximate?'近似采样分析':'完整点集分析'}：${sampling.source_count} → ${sampling.sample_count} 点；覆盖半径 ${sampling.covering_radius}（分析坐标单位）。该半径不是持久图区间误差保证。原始编号保存在 source 数据中。`;}
    #|function node(tag,attrs={},text=''){const n=document.createElementNS(NS,tag);for(const [k,v]of Object.entries(attrs))n.setAttribute(k,String(v));if(text)n.textContent=text;return n;}
    #|const end=i=>i.death===null?DATA.cutoff:i.death,life=i=>Math.max(0,end(i)-i.birth);
    #|const live=(i,s)=>i.birth<=s&&(i.death===null||s<i.death);
    #|const fmt=x=>x===null?'截止仍存在':String(Number(Number(x).toPrecision(4)));
    #|let low=DATA.cells.reduce((v,c)=>Math.min(v,c.value),DATA.cutoff),selected=-1,current=DATA.cutoff,page=0;
    #|if(DATA.homology_dimension===2){el('h2-card').hidden=false;const option=document.createElement('option');option.value='2';option.textContent='H2 空腔';el('dimension').append(option);}
    #|el('meta').textContent=`复形类型 ${DATA.kind} · ${DATA.vertex_count} 个顶点 · 截止尺度 ${fmt(DATA.cutoff)} · ${DATA.column_additions} 次列加法`;
    #|el('cells').textContent=String(DATA.cell_count);el('longest').textContent=DATA.summary[1].longest_finite_lifetime===null?'—':fmt(DATA.summary[1].longest_finite_lifetime);
    #|el('projection-note').textContent=DATA.kind==='cubical_volume'&&DATA.representatives_computed===false?'仅区间模式未生成三维代表面或切片；仍可查看区间与 Betti 曲线。':DATA.kind==='cubical_volume'?'三维体数据请打开同目录 volume-slices.html 按 Z 层查看；此处仍展示全体区间与 Betti 曲线。':DATA.positions.length?'按输入坐标投影；网格使用列坐标与负行坐标。':'此输入不含几何坐标，可通过区间表与曲线观察拓扑。';
    #|const has3D=DATA.kind!=='cubical_volume'&&DATA.kind!=='cubical'&&DATA.positions.some(p=>p.length>=3);el('rotation-controls').hidden=!has3D;
    #|el('censor-note').textContent=DATA.summary.map(s=>`H${s.dimension}：${s.alive_at_cutoff} 个区间在截止处仍存活，有限持续熵与景观不计入这些区间`).join('；')+'。它们的真实死亡尺度尚未观察到，不能按零寿命或无限寿命解释。';
    #|function renderSource(){const interval=DATA.intervals[selected],body=el('source-rows');body.replaceChildren();el('source-panel').hidden=!interval||DATA.representatives_computed===false;if(!interval||DATA.representatives_computed===false)return;const ids=[...new Set(interval.representative.flatMap(i=>DATA.cells[i].vertices))].sort((a,b)=>a-b),csv=DATA.source?.csv;el('source-meaning').textContent=csv?`列：${csv.headers.join(', ')}；${csv.index_meaning}；显示变换前的原始数值。`:'编号对应原始点数组；显示输入坐标。';for(const id of ids){const original=csv?.window_data_row_indices?.[id]??csv?.data_row_indices?.[id]??DATA.source?.sampling?.source_indices?.[id]??id,values=csv?.selected_raw_rows?.[id]??DATA.positions[id]??[];const row=document.createElement('tr');for(const value of [id,JSON.stringify(original),JSON.stringify(values)]){const td=document.createElement('td');td.textContent=String(value);row.append(td);}body.append(row);}}
    #|function counts(scale){return Array.from({length:DATA.homology_dimension+1},(_,d)=>DATA.intervals.filter(i=>i.dimension===d&&live(i,scale)).length);}
    #|const curveSamples=DATA.betti_events.map(p=>({s:p.scale,b:DATA.homology_dimension===2?[p.h0,p.h1,p.h2]:[p.h0,p.h1]})),curveTop=curveSamples.reduce((top,p)=>Math.max(top,...p.b),1);
    #|function renderGeometry(){
    #| renderSource();const svg=el('geometry');svg.replaceChildren();if(DATA.kind==='cubical_volume'){svg.append(node('text',{x:35,y:180,fill:'#94a3b8'},DATA.representatives_computed===false?'仅区间模式未生成三维代表面；请查看区间与 Betti 曲线':'请打开 volume-slices.html 查看三维切片'));return;}if(!DATA.positions.length){svg.append(node('text',{x:35,y:180,fill:'#94a3b8'},'距离矩阵无几何坐标'));return;}
    #| const mode3D=has3D&&el('projection-mode').value==='3d',yaw=Number(el('yaw').value||0)*Math.PI/180,pitch=Number(el('pitch').value||0)*Math.PI/180;
    #| const center=Array.from({length:3},(_,d)=>{const values=DATA.positions.map(p=>p[d]||0);return Math.min(...values)/2+Math.max(...values)/2;});
    #| const projected=DATA.positions.map(p=>{if(!mode3D)return [p[0],p[1]];const x=p[0]-center[0],y=p[1]-center[1],z=(p[2]||0)-center[2],rx=x*Math.cos(yaw)+z*Math.sin(yaw),rz=-x*Math.sin(yaw)+z*Math.cos(yaw);return [rx,y*Math.cos(pitch)-rz*Math.sin(pitch)];});
    #| let minX=Infinity,maxX=-Infinity,minY=Infinity,maxY=-Infinity;
    #| for(const p of projected){minX=Math.min(minX,p[0]);maxX=Math.max(maxX,p[0]);minY=Math.min(minY,p[1]);maxY=Math.max(maxY,p[1]);}
    #| const span=Math.max(maxX-minX,maxY-minY)||1,xy=i=>{const p=projected[i];return p?[320+330*((p[0]-minX)/span-(maxX-minX)/span/2),215-330*((p[1]-minY)/span-(maxY-minY)/span/2)]:null;};
    #| const chosen=DATA.representatives_computed===false?null:DATA.intervals[selected],highlight=new Set(chosen&&chosen.dimension===1&&live(chosen,current)?chosen.representative:[]);
    #| if(DATA.kind==='cubical')for(let i=0;i<DATA.cells.length;i++){const c=DATA.cells[i];if(c.dimension!==2||c.value>current)continue;const [a,b,d,e]=[c.vertices[0],c.vertices[1],c.vertices[3],c.vertices[2]].map(xy);if(!a||!b||!d||!e)continue;const face=node('polygon',{'data-cell-index':i,points:[a,b,d,e].map(p=>p.join(',')).join(' '),fill:'#2dd4bf','fill-opacity':.22});face.append(node('title',{},`已填充方格 #${i}，进入尺度 ${fmt(c.value)}`));svg.append(face);}
    #| for(let i=0;i<DATA.cells.length;i++){const c=DATA.cells[i];if(c.dimension!==1||c.value>current)continue;const a=xy(c.vertices[0]),b=xy(c.vertices[1]);if(!a||!b)continue;svg.append(node('line',{x1:a[0],y1:a[1],x2:b[0],y2:b[1],stroke:highlight.has(i)?'#fb923c':'#465671','stroke-width':highlight.has(i)?4:1,opacity:highlight.has(i)?1:.55}));}
    #| for(const c of DATA.cells){if(c.dimension!==0||c.value>current)continue;const p=xy(c.vertices[0]);if(p){const dot=node('circle',{cx:p[0],cy:p[1],r:4,fill:'#38bdf8'});dot.append(node('title',{},`顶点 ${c.vertices[0]}`));svg.append(dot);}}
    #|}
    #|function renderTable(){
    #| const dim=el('dimension').value,min=Number(el('minimum').value),only=el('alive-only').checked;
    #| const rows=DATA.intervals.map((i,index)=>({i,index})).filter(({i})=>(dim==='all'||i.dimension===Number(dim))&&life(i)>=(Number.isFinite(min)&&min>=0?min:0)&&(!only||live(i,current))).sort((a,b)=>life(b.i)-life(a.i)||a.index-b.index);
    #| const size=50,pages=Math.max(1,Math.ceil(rows.length/size));page=Math.min(page,pages-1);const first=page*size,last=Math.min(first+size,rows.length);
    #| const body=el('interval-table');body.replaceChildren();el('table-count').textContent=`符合条件 ${rows.length} 个，显示 ${rows.length?first+1:0}–${last} 个`;
    #| el('page-status').textContent=`第 ${page+1} / ${pages} 页`;el('previous-page').disabled=page===0;el('next-page').disabled=page>=pages-1;
    #| for(const {i,index}of rows.slice(first,last)){const row=document.createElement('tr');if(index===selected)row.className='selected';const cell=document.createElement('td'),button=document.createElement('button');button.textContent=`#${index}`;button.disabled=DATA.representatives_computed===false;button.setAttribute('aria-pressed',String(index===selected));button.addEventListener('click',()=>{selected=index;if(i.dimension===1&&!live(i,current)){renderAt(i.birth);}else{renderTable();renderGeometry();}el('selection-note').textContent=i.dimension===1?`已选择 #${index}；橙色代表环路仅在该区间存活时显示。`:`已选择 H${i.dimension} 区间 #${index}；此投影仅高亮 H1 环路。`;});cell.append(button);row.append(cell);for(const text of [`H${i.dimension}`,fmt(i.birth),fmt(i.death),fmt(life(i))]){const td=document.createElement('td');td.textContent=text;row.append(td);}body.append(row);}
    #|}
    #|function renderCurve(){
    #| const svg=el('curve');svg.replaceChildren();const samples=curveSamples,top=curveTop,xAt=s=>DATA.cutoff===low?970:50+(s-low)/(DATA.cutoff-low)*920;
    #| svg.append(node('path',{d:'M 50 20 V 210 H 970',fill:'none',stroke:'#64748b'}));
    #| for(const d of Array.from({length:DATA.homology_dimension+1},(_,i)=>i))svg.append(node('polyline',{points:samples.flatMap((p,i)=>i?[`${xAt(p.s)},${210-samples[i-1].b[d]/top*180}`,`${xAt(p.s)},${210-p.b[d]/top*180}`]:[`${xAt(p.s)},${210-p.b[d]/top*180}`]).join(' '),fill:'none',stroke:['#38bdf8','#fb923c','#a78bfa'][d],'stroke-width':2}));
    #| svg.append(node('text',{x:50,y:238,fill:'#94a3b8'},fmt(low)));svg.append(node('text',{x:900,y:238,fill:'#94a3b8'},fmt(DATA.cutoff)));svg.append(node('text',{x:8,y:25,fill:'#94a3b8'},String(top)));
    #| const x=DATA.cutoff===low?970:50+(current-low)/(DATA.cutoff-low)*920;svg.append(node('line',{x1:x,x2:x,y1:20,y2:210,stroke:'#e2e8f0','stroke-dasharray':'4 4'}));
    #|}
    #|function renderAt(scale,syncInput=true){current=scale;if(syncInput)el('scale-exact').value=String(current);el('scale-message').textContent='';el('scale').value=String(DATA.cutoff===low?1000:1000*(current-low)/(DATA.cutoff-low));el('event-previous').disabled=!curveSamples.some(p=>p.s<current);el('event-next').disabled=!curveSamples.some(p=>p.s>current);el('scale-value').textContent=fmt(current);const b=counts(current);el('h0').textContent=String(b[0]);el('h1').textContent=String(b[1]);if(DATA.homology_dimension===2)el('h2').textContent=String(b[2]);renderTable();renderGeometry();renderCurve();}
    #|function refresh(){const v=Number(el('scale').value);renderAt(v===1000?DATA.cutoff:low+(DATA.cutoff-low)*v/1000);}el('scale-exact').min=String(low);el('scale-exact').max=String(DATA.cutoff);el('scale-exact').addEventListener('input',()=>{const s=Number(el('scale-exact').value);if(el('scale-exact').value.trim()===''||!Number.isFinite(s)||s<low||s>DATA.cutoff){el('scale-message').textContent=`请输入 ${fmt(low)} 至 ${fmt(DATA.cutoff)} 之间的尺度`;return;}el('scale-message').textContent='';renderAt(s,false);});for(const [id,direction]of [['event-previous',-1],['event-next',1]])el(id).addEventListener('click',()=>{const events=curveSamples.filter(p=>direction<0?p.s<current:p.s>current);if(events.length)renderAt(direction<0?events[events.length-1].s:events[0].s);});el('scale').addEventListener('input',refresh);for(const id of ['dimension','minimum','alive-only'])el(id).addEventListener('input',()=>{page=0;renderTable();});
    #|for(const id of ['projection-mode','yaw','pitch'])el(id).addEventListener('input',renderGeometry);el('rotation-reset').addEventListener('click',()=>{el('yaw').value='0';el('pitch').value='0';renderGeometry();});
    #|el('previous-page').addEventListener('click',()=>{if(page>0){page--;renderTable();}});el('next-page').addEventListener('click',()=>{page++;renderTable();});refresh();if(DATA.representatives_computed===false)el('selection-note').textContent='仅区间模式：未计算代表链，几何投影仍可查看，但环路和代表面高亮不可用。';
    #|</script></body></html>
  header + data + script
}
