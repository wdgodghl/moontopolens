///|
/// Offline vertex-slice explorer for a three-dimensional cubical filtration.
/// Homology and cell values are embedded from MoonBit; JavaScript only filters
/// already computed values for display.
pub fn volume_slices_html(analysis : Analysis) -> String raise TopologyError {
  if analysis.filtration.kind != "cubical_volume" {
    raise TopologyError("volume slice report requires cubical_volume input")
  }
  let data = report_json(analysis)
    .stringify()
    .replace_all(old="<", new="\\u003c")
  let header =
    #|<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MoonTopoLens · 三维体素切片</title>
    #|<style>*{box-sizing:border-box}body{margin:0;background:#0b1120;color:#e2e8f0;font:15px/1.6 system-ui,sans-serif}main{max-width:1000px;margin:auto;padding:28px 20px}h1{margin:0 0 8px;font-size:30px}h2{font-size:19px}.muted{color:#94a3b8}.panel{background:#111c30;border:1px solid #26354f;border-radius:14px;padding:20px;margin:18px 0}.controls{display:flex;gap:20px;flex-wrap:wrap;align-items:center}.controls label{display:grid;gap:5px}select,input{font:inherit;color:#e2e8f0;background:#16263e;border:1px solid #43526c;border-radius:7px;padding:6px}input[type=range]{width:min(440px,80vw)}svg{display:block;width:100%;max-width:650px;background:#0b1426;border-radius:10px;margin:16px auto}.metrics{display:flex;gap:14px;flex-wrap:wrap}.metric{min-width:130px;padding:12px;border-radius:8px;background:#17253b}.metric strong{display:block;font-size:24px;color:#7dd3fc}</style></head><body><main><h1>MoonTopoLens · 三维体素切片</h1><p class=muted>按 Z 层查看顶点值进入过滤复形的过程。H0/H1/H2 是整个三维复形的结果，并非单张切片的同调。</p><section class=panel><div class=controls><label>切片层 Z<select id="layer"></select></label><label>尺度 <output id="scale-value"></output><input id="scale" type="range" min="0" max="1000" value="1000"></label></div><div class=metrics><div class=metric>连通分量 H0<strong id="h0"></strong></div><div class=metric>环路 H1<strong id="h1"></strong></div><div class=metric>空腔 H2<strong id="h2"></strong></div></div><svg id="slice" role="img" aria-label="体素顶点切片"></svg><p id="slice-note" class=muted></p><p class=muted>青色表示顶点值不高于当前尺度；深色表示尚未进入。灰色顶点值高于分析截止尺度。单个格子表示一个采样顶点，不代表整个体素立方体已进入。</p></section><p><a href="report.html" style="color:#93c5fd">查看完整条形码、持续图和区间报告</a></p><footer class=muted>全部过滤复形与持续同调由 MoonBit 计算。本页可离线打开。</footer></main><script id="volume-data" type="application/json">
  let script =
    #|</script><script>'use strict';
    #|const DATA=JSON.parse(document.getElementById('volume-data').textContent),$=id=>document.getElementById(id),NS='http://www.w3.org/2000/svg';
    #|const fmt=x=>String(Number(Number(x).toPrecision(5))),positions=DATA.positions,values=new Map(DATA.cells.filter(c=>c.dimension===0).map(c=>[c.vertices[0],c.value]));
    #|const width=1+Math.max(...positions.map(p=>p[0])),height=1+Math.max(...positions.map(p=>-p[1])),depth=1+Math.max(...positions.map(p=>p[2]));
    #|const low=DATA.cells.reduce((n,c)=>Math.min(n,c.value),DATA.cutoff),layer=$('layer');for(let z=0;z<depth;z++){const option=document.createElement('option');option.value=String(z);option.textContent=`Z = ${z}`;layer.append(option);}
    #|function svg(tag,attrs={},label=''){const element=document.createElementNS(NS,tag);for(const [key,value]of Object.entries(attrs))element.setAttribute(key,String(value));if(label)element.textContent=label;return element;}
    #|function update(){const z=Number(layer.value),step=Number($('scale').value),scale=step===1000?DATA.cutoff:low+(DATA.cutoff-low)*step/1000; $('scale-value').textContent=fmt(scale);for(let dim=0;dim<3;dim++)$('h'+dim).textContent=String(DATA.intervals.filter(i=>i.dimension===dim&&i.birth<=scale&&(i.death===null||scale<i.death)).length);const view=$('slice'),size=Math.min(54,Math.floor(560/Math.max(width,height)));view.setAttribute('viewBox',`0 0 ${width*size+60} ${height*size+60}`);view.replaceChildren();let active=0;for(let y=0;y<height;y++)for(let x=0;x<width;x++){const index=(z*height+y)*width+x,value=values.get(index),entered=value!==undefined&&value<=scale;if(entered)active++;const rect=svg('rect',{x:30+x*size,y:30+y*size,width:size-2,height:size-2,rx:3,fill:entered?'#2dd4bf':value===undefined?'#475569':'#17253b'});rect.append(svg('title',{},`(${x},${y},${z}) · ${value===undefined?'高于截止尺度':fmt(value)}`));view.append(rect);} $('slice-note').textContent=`第 ${z+1}/${depth} 层 · ${width}×${height} 个采样顶点 · 当前进入 ${active} 个`;}
    #|layer.addEventListener('input',update);$('scale').addEventListener('input',update);update();</script></body></html>
  header + data + script
}
