///|
/// A self-contained offline report. JavaScript only displays precomputed results:
/// slider filtering, table selection and 2D projection; no homology runs in UI.
/// JSON escapes '<' so public cell keys cannot terminate the data script.
pub fn html_report(analysis : Analysis) -> String {
  let data = report_json(analysis)
    .stringify()
    .replace_all(old="<", new="\\u003c")
  let header =
    #|<!doctype html>
    #|<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    #|<title>MoonTopoLens · 月拓镜分析报告</title>
    #|<style>
    #|*{box-sizing:border-box}body{margin:0;background:#0b1120;color:#e2e8f0;font:15px/1.6 system-ui,sans-serif}
    #|main{max-width:1180px;margin:auto;padding:30px 24px}h1{margin:0;font-size:32px}h2{font-size:18px;margin:0 0 12px}
    #|small,.muted{color:#94a3b8}header{margin-bottom:24px}.tag{display:inline-block;background:#123448;color:#7dd3fc;padding:3px 10px;border-radius:20px}
    #|.cards{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin:20px 0}.card,.panel{background:#111c30;border:1px solid #26354f;border-radius:14px;padding:18px}
    #|.value{font-size:28px;font-weight:650}.layout{display:grid;grid-template-columns:1.15fr 1fr;gap:18px}.controls{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin:12px 0}
    #|input[type=range]{width:100%;accent-color:#38bdf8}input[type=number]{width:100px}select,input,button{font:inherit;color:#e2e8f0;background:#16263e;border:1px solid #43526c;border-radius:7px;padding:6px}
    #|button{cursor:pointer}button:hover,button[aria-pressed=true]{border-color:#fb923c}svg{width:100%;background:#0b1426;border-radius:10px}table{width:100%;border-collapse:collapse;font-size:13px}th,td{text-align:left;padding:8px;border-bottom:1px solid #26354f}th{color:#94a3b8}tr.selected{background:#243454}
    #|.table-wrap{max-height:410px;overflow:auto}.blue{color:#38bdf8}.orange{color:#fb923c}.notice{border-left:3px solid #fb923c;padding:8px 14px;background:#192233;margin:16px 0}footer{margin-top:20px;color:#94a3b8;font-size:13px}
    #|@media(max-width:850px){.layout{grid-template-columns:1fr}.cards{grid-template-columns:repeat(2,1fr)}}
    #|</style></head><body><main>
    #|<header><span class="tag">OFFLINE REPORT / GF(2)</span><h1>MoonTopoLens <span class="muted">月拓镜</span></h1><p>观察尺度变化中的连接分量与闭合环路。此报告可离线打开，不会上传数据。</p><small id="meta"></small></header>
    #|<section class="cards" aria-label="拓扑摘要"><div class="card"><small>当前连接分量 H0</small><div class="value blue" id="h0"></div></div><div class="card"><small>当前环路 H1</small><div class="value orange" id="h1"></div></div><div class="card"><small>细胞总数</small><div class="value" id="cells"></div></div><div class="card"><small>H1 最长有限寿命</small><div class="value" id="longest"></div></div></section>
    #|<section class="panel"><h2>选择观察尺度</h2><label for="scale">尺度 <output id="scale-value"></output></label><input id="scale" type="range" min="0" max="1000" value="1000"><small>统计采用 [出生,死亡) 区间；截止处仍存在的类不代表无限寿命。</small></section>
    #|<div class="layout" style="margin-top:18px"><section class="panel"><h2>几何投影与代表环路</h2><p class="muted" id="projection-note"></p><svg id="geometry" viewBox="0 0 640 430" role="img" aria-label="过滤复形的二维投影"></svg><small>灰线为当前进入的边，橙线为选中环路在出生时的代表；三角形填充未绘制。</small></section>
    #|<section class="panel"><h2>区间筛选与排名</h2><div class="controls"><label>维度 <select id="dimension"><option value="1">H1 环路</option><option value="0">H0 分量</option><option value="all">全部</option></select></label><label>最小观察寿命 <input id="minimum" type="number" min="0" value="0" step="any"></label><label><input id="alive-only" type="checkbox">仅当前存活</label></div><small id="table-count"></small><div class="table-wrap"><table><thead><tr><th>选择</th><th>维度</th><th>出生</th><th>死亡</th><th>观察寿命</th></tr></thead><tbody id="interval-table"></tbody></table></div><small>未死亡区间以截止尺度减出生尺度作为寿命下界。最多展示前 200 行；CSV 和 JSON 保留全部数据。</small></section></div>
    #|<section class="panel" style="margin-top:18px"><h2>Betti 曲线</h2><svg id="curve" viewBox="0 0 1000 250" role="img" aria-label="H0 和 H1 随尺度变化的曲线"></svg><small>蓝色 H0 / 橙色 H1；按 101 个尺度采样，短暂区间可能落在采样点之间。</small></section>
    #|<div class="notice">代表环路用于解释计算结果，不保证最短。高维点云仅投影前两个坐标，投影交叉不代表原空间相交。距离矩阵没有几何坐标时仍可查看全部拓扑结果。</div>
    #|<footer>由 MoonBit 核心计算生成。配套文件：report.json、intervals.csv、betti.csv、barcode.svg、diagram.svg。</footer>
    #|</main><script id="topology-data" type="application/json">
  let script =
    #|</script><script>
    #|'use strict';
    #|const DATA=JSON.parse(document.getElementById('topology-data').textContent);
    #|const el=id=>document.getElementById(id), NS='http://www.w3.org/2000/svg';
    #|function node(tag,attrs={},text=''){const n=document.createElementNS(NS,tag);for(const [k,v]of Object.entries(attrs))n.setAttribute(k,String(v));if(text)n.textContent=text;return n;}
    #|const end=i=>i.death===null?DATA.cutoff:i.death,life=i=>Math.max(0,end(i)-i.birth);
    #|const live=(i,s)=>i.birth<=s&&(i.death===null||s<i.death);
    #|const fmt=x=>x===null?'截止仍存在':String(Number(Number(x).toPrecision(4)));
    #|let low=DATA.cells.reduce((v,c)=>Math.min(v,c.value),DATA.cutoff),selected=-1,current=DATA.cutoff;
    #|el('meta').textContent=`复形类型 ${DATA.kind} · ${DATA.vertex_count} 个顶点 · 截止尺度 ${fmt(DATA.cutoff)} · ${DATA.column_additions} 次列加法`;
    #|el('cells').textContent=String(DATA.cell_count);el('longest').textContent=DATA.summary[1].longest_finite_lifetime===null?'—':fmt(DATA.summary[1].longest_finite_lifetime);
    #|el('projection-note').textContent=DATA.positions.length?'按输入坐标投影；网格使用列坐标与负行坐标。':'此输入不含几何坐标，可通过区间表与曲线观察拓扑。';
    #|function counts(scale){return[0,1].map(d=>DATA.intervals.filter(i=>i.dimension===d&&live(i,scale)).length);}
    #|const curveSamples=Array.from({length:101},(_,i)=>{const s=i===100?DATA.cutoff:low+(DATA.cutoff-low)*i/100;return{s,b:counts(s)};}),curveTop=Math.max(1,...curveSamples.flatMap(p=>p.b));
    #|function renderGeometry(){
    #| const svg=el('geometry');svg.replaceChildren();if(!DATA.positions.length){svg.append(node('text',{x:35,y:180,fill:'#94a3b8'},'距离矩阵无几何坐标'));return;}
    #| let minX=Infinity,maxX=-Infinity,minY=Infinity,maxY=-Infinity;
    #| for(const p of DATA.positions){minX=Math.min(minX,p[0]);maxX=Math.max(maxX,p[0]);minY=Math.min(minY,p[1]);maxY=Math.max(maxY,p[1]);}
    #| const span=Math.max(maxX-minX,maxY-minY)||1,xy=i=>{const p=DATA.positions[i];return p?[320+330*((p[0]-minX)/span-(maxX-minX)/span/2),215-330*((p[1]-minY)/span-(maxY-minY)/span/2)]:null;};
    #| const chosen=DATA.intervals[selected],highlight=new Set(chosen&&chosen.dimension===1&&live(chosen,current)?chosen.representative:[]);
    #| for(let i=0;i<DATA.cells.length;i++){const c=DATA.cells[i];if(c.dimension!==1||c.value>current)continue;const a=xy(c.vertices[0]),b=xy(c.vertices[1]);if(!a||!b)continue;svg.append(node('line',{x1:a[0],y1:a[1],x2:b[0],y2:b[1],stroke:highlight.has(i)?'#fb923c':'#465671','stroke-width':highlight.has(i)?4:1,opacity:highlight.has(i)?1:.55}));}
    #| for(const c of DATA.cells){if(c.dimension!==0||c.value>current)continue;const p=xy(c.vertices[0]);if(p){const dot=node('circle',{cx:p[0],cy:p[1],r:4,fill:'#38bdf8'});dot.append(node('title',{},`顶点 ${c.vertices[0]}`));svg.append(dot);}}
    #|}
    #|function renderTable(){
    #| const dim=el('dimension').value,min=Number(el('minimum').value),only=el('alive-only').checked;
    #| const rows=DATA.intervals.map((i,index)=>({i,index})).filter(({i})=>(dim==='all'||i.dimension===Number(dim))&&life(i)>=(Number.isFinite(min)&&min>=0?min:0)&&(!only||live(i,current))).sort((a,b)=>life(b.i)-life(a.i)||a.index-b.index);
    #| const body=el('interval-table');body.replaceChildren();el('table-count').textContent=`符合条件 ${rows.length} 个，显示 ${Math.min(200,rows.length)} 个`;
    #| for(const {i,index}of rows.slice(0,200)){const row=document.createElement('tr');if(index===selected)row.className='selected';const cell=document.createElement('td'),button=document.createElement('button');button.textContent=`#${index}`;button.setAttribute('aria-pressed',String(index===selected));button.addEventListener('click',()=>{selected=index;renderTable();renderGeometry();});cell.append(button);row.append(cell);for(const text of [`H${i.dimension}`,fmt(i.birth),fmt(i.death),fmt(life(i))]){const td=document.createElement('td');td.textContent=text;row.append(td);}body.append(row);}
    #|}
    #|function renderCurve(){
    #| const svg=el('curve');svg.replaceChildren();const samples=curveSamples,top=curveTop;
    #| svg.append(node('path',{d:'M 50 20 V 210 H 970',fill:'none',stroke:'#64748b'}));
    #| for(const d of [0,1])svg.append(node('polyline',{points:samples.flatMap((p,i)=>i?[`${50+i*9.2},${210-samples[i-1].b[d]/top*180}`,`${50+i*9.2},${210-p.b[d]/top*180}`]:[`${50+i*9.2},${210-p.b[d]/top*180}`]).join(' '),fill:'none',stroke:d?'#fb923c':'#38bdf8','stroke-width':2}));
    #| svg.append(node('text',{x:50,y:238,fill:'#94a3b8'},fmt(low)));svg.append(node('text',{x:900,y:238,fill:'#94a3b8'},fmt(DATA.cutoff)));svg.append(node('text',{x:8,y:25,fill:'#94a3b8'},String(top)));
    #| const x=DATA.cutoff===low?970:50+(current-low)/(DATA.cutoff-low)*920;svg.append(node('line',{x1:x,x2:x,y1:20,y2:210,stroke:'#e2e8f0','stroke-dasharray':'4 4'}));
    #|}
    #|function refresh(){current=low+(DATA.cutoff-low)*Number(el('scale').value)/1000;if(Number(el('scale').value)===1000)current=DATA.cutoff;el('scale-value').textContent=fmt(current);const b=counts(current);el('h0').textContent=String(b[0]);el('h1').textContent=String(b[1]);renderTable();renderGeometry();renderCurve();}
    #|el('scale').addEventListener('input',refresh);for(const id of ['dimension','minimum','alive-only'])el(id).addEventListener('input',renderTable);refresh();
    #|</script></body></html>
  header + data + script
}
