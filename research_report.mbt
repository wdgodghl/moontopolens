///|
pub fn research_csv(
  report : Json,
  field~ : String = "rows",
) -> String raise TopologyError {
  let f = batch_object(report, "research report")
  let rows : Array[Json] = match f.get(field) {
    None => []
    Some(Null) => []
    Some(v) =>
      @json.from_json(v) catch {
        _ => raise TopologyError("report field is not rows")
      }
  }
  if rows.is_empty() {
    return ""
  }
  let first = batch_object(rows[0], "report row")
  let columns : Array[String] = []
  for key in first.keys() {
    match first[key] {
      Object(_) | Array(_) => ()
      _ => columns.push(key)
    }
  }
  columns.sort()
  let output : Array[Array[Json]] = []
  for row in rows {
    let fields = batch_object(row, "report row")
    output.push(
      columns.map(fn(key) {
        match fields.get(key) {
          Some(value) => value
          None => Json::null()
        }
      }),
    )
  }
  research_csv_rows(columns, output)
}

///|
/// Offline display only: statistics and segmentation are precomputed in MoonBit.
pub fn research_html(report : Json) -> String {
  let data = report.stringify().replace_all(old="<", new="\\u003c")
  let head =
    #|<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MoonTopoLens 研究报告</title>
    #|<style>*{box-sizing:border-box}body{margin:0;background:#0b1120;color:#e2e8f0;font:15px/1.65 system-ui,sans-serif}main{max-width:1180px;padding:28px 20px;margin:auto}h1{font-size:30px;margin:0}h2{font-size:20px}.panel{margin:18px 0;padding:20px;border:1px solid #334155;border-radius:12px;background:#111c30}.muted{color:#cbd5e1}.scroll{overflow:auto;max-height:520px}table{border-collapse:collapse;min-width:650px;width:100%;font-size:13px}th,td{border-bottom:1px solid #475569;padding:8px;text-align:left}button,input,select{font:inherit;background:#17253b;color:#e2e8f0;border:1px solid #64748b;border-radius:5px;padding:6px}button{cursor:pointer}a{color:#93c5fd}.controls{display:flex;flex-wrap:wrap;align-items:center;gap:12px}.controls label{display:flex;gap:8px;align-items:center}svg{display:block;width:100%;background:#0b1426;margin:12px 0}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:13px/1.6 system-ui}.notice{border-left:3px solid #fbbf24;padding:12px;background:#17253b}#detail{max-height:400px;overflow:auto}@media(max-width:600px){main{padding:18px 12px}.panel{padding:12px}h1{font-size:25px}}</style></head><body><main><h1 id="title">MoonTopoLens 研究报告</h1><p class="muted">离线查看计算结果、原始数据位置与分析条件。</p><p id="interpretation" class="notice"></p><section class="panel"><h2>分析设置与摘要</h2><pre id="summary"></pre></section>
    #|<section class="panel" id="visual-panel"><h2 id="visual-title">结果图</h2><div class="controls" id="pore-controls" hidden><label>孔洞标签<select id="pore-label"><option value="0">全部</option></select></label><label>切片 Z<input id="slice" type="range" min="0" max="0" value="0"></label><label>水平旋转<input id="angle" type="range" min="-180" max="180" value="30"></label><label>俯仰<input id="tilt" type="range" min="-80" max="80" value="20"></label></div><svg id="chart" role="img" aria-label="预计算研究结果图，完整数值见结果表" viewBox="0 0 1000 300"></svg><svg id="geometry" role="img" aria-label="选中数据的坐标投影或孔洞体素表面" viewBox="0 0 640 400" hidden></svg><p id="visual-note"></p></section>
    #|<section class="panel"><h2>结果明细</h2><p>选择一行可查看对应原始数据、区间或空间区域；完整结果保存在 report.json 和配套 CSV 中。</p><div class="scroll"><table><thead id="head"></thead><tbody id="rows"></tbody></table></div></section><section class="panel" id="detail-panel" hidden><h2>所选结果与来源</h2><pre id="detail" tabindex="0" role="region" aria-label="所选结果详情，可滚动"></pre><button id="export-window" type="button" hidden>下载所选窗口分析请求</button></section><div id="extra"></div><p id="selection-status" role="status" aria-live="polite"></p><footer><a href="report.json">完整 JSON</a> · <a href="rows.csv">结果 CSV</a><span id="mesh-link" hidden> · <a href="pores.obj">孔洞 OBJ 表面</a> · <a href="labels.json">区域标签</a></span></footer></main><script id="research-data" type="application/json">
  let tail =
    #|</script><script>'use strict';
    #|const D=JSON.parse(document.getElementById('research-data').textContent),$=id=>document.getElementById(id),NS='http://www.w3.org/2000/svg';let selected=0;const names={reliability:'可靠性与敏感性分析',signal_study:'长信号状态变化',cohort:'分组拓扑比较',pores:'孔洞空间定量',pore_compare:'孔洞区域变化'};$('title').textContent=`MoonTopoLens · ${names[D.kind]||D.kind}`;$('interpretation').textContent=D.interpretation||D.assumptions||'';
    #|const labels={scale:'尺度',mean:'均值',lower:'下界',upper:'上界',mean_A:'A 组均值',mean_B:'B 组均值',effect_A_minus_B:'均值差 A−B',p_raw:'原始 p',p_max_adjusted:'多尺度校正 p',window_index:'窗口编号',start:'起始时间',end:'结束时间',anomaly:'拓扑异常',monitoring:'监测时段',label:'孔洞标签',volume:'体积',voxel_count:'体素数',touches_crop:'接触裁剪边界',solid_interface_area:'固体界面面积',crop_cap_area:'裁剪封口面积',contained_ball_radius_at_voxel_center:'体素中心内切球半径',cutoff:'截止尺度',size:'重采样量',trial:'重复编号',support_frequency:'匹配重复率',retained:'保留次数',trials:'总次数',global_p_exact:'精确全局 p',pore_fraction:'孔隙体积分数',pore_volume:'孔隙体积'};
    #|const fmt=x=>x===null?'—':typeof x==='number'?Number(x.toPrecision(6)).toString():typeof x==='object'?JSON.stringify(x):String(x);const primitive=o=>Object.keys(o).filter(k=>o[k]===null||typeof o[k]!=='object');const summary={};for(const k of primitive(D))summary[labels[k]||k]=D[k];if(D.assumptions)summary['统计假设']=D.assumptions;if(D.thresholds)summary['方法阈值（顺序见 JSON）']=D.thresholds;if(D.offsets)summary['共同变换偏移']=D.offsets;if(D.scales)summary['共同变换缩放']=D.scales;$('summary').textContent=JSON.stringify(summary,null,2);
    #|function node(tag,a={},text=''){const n=document.createElementNS(NS,tag);for(const [k,v]of Object.entries(a))n.setAttribute(k,String(v));if(text)n.textContent=text;return n;}
    #|function lines(series,xs){const svg=$('chart');svg.replaceChildren();const all=series.flatMap(s=>s.values).filter(Number.isFinite);if(!all.length||!xs.length){svg.append(node('text',{x:30,y:80,fill:'#cbd5e1'},'此结果没有可绘制的曲线；请查看结果表'));return;}const lo=Math.min(0,...all),hi=Math.max(...all),span=hi-lo||1,xlo=xs[0],xhi=xs[xs.length-1],at=(x,y)=>[50+(x-xlo)/(xhi-xlo||1)*900,250-(y-lo)/span*210];svg.append(node('path',{d:'M50 20 V250 H950',stroke:'#94a3b8',fill:'none'}));for(const [i,s]of series.entries()){const pairs=s.values.map((v,j)=>Number.isFinite(v)?at(xs[j],v):null);let segment=[];const flush=()=>{if(segment.length)svg.append(node('polyline',{points:segment.map(p=>p.join(',')).join(' '),fill:'none',stroke:s.color,'stroke-width':2}));segment=[];};for(const p of pairs){if(p)segment.push(p);else flush();}flush();svg.append(node('text',{x:60+i*270,y:285,fill:s.color},s.name));}svg.append(node('text',{x:50,y:17,fill:'#cbd5e1'},fmt(hi)));}
    #|function table(target,rows,selectable=false){const table=target.tagName==='TABLE'?target:target.querySelector('table');if(!rows.length){const caption=document.createElement('caption');caption.textContent='无记录';table.append(caption);return;}const columns=primitive(rows[0]);const tr=document.createElement('tr');if(selectable){const th=document.createElement('th');th.textContent='选择';tr.append(th);}for(const c of columns){const th=document.createElement('th');th.textContent=labels[c]||c;th.scope='col';tr.append(th);}const head=table.querySelector('thead'),body=table.querySelector('tbody');head.replaceChildren(tr);body.replaceChildren();for(const [i,r]of rows.entries()){const line=document.createElement('tr');if(selectable){const td=document.createElement('td'),b=document.createElement('button');b.textContent=`查看第 ${i+1} 条结果`;b.setAttribute('aria-label',`查看第 ${i+1} 条结果`);b.addEventListener('click',()=>choose(i));td.append(b);line.append(td);}for(const c of columns){const td=document.createElement('td');td.textContent=fmt(r[c]);line.append(td);}body.append(line);}}
    #|function sampleView(i){const s=D.samples[i],a=s.analysis;$('detail-panel').hidden=false;$('detail').textContent=JSON.stringify({name:s.name,group:s.group,distance_to_group_mean:s.distance_to_group_mean,original_request:s.original_request},null,2);const interval=a.intervals.filter(t=>t.dimension===1).sort((x,y)=>((y.death??a.cutoff)-y.birth)-((x.death??a.cutoff)-x.birth))[0];const edges=(interval?.representative||[]).map(i=>a.cells[i].vertices).filter(v=>v.length===2);geometry(s.original_request.points||a.positions,edges);$('selection-status').textContent=`已选择样本 ${s.name}；显示原始点坐标的前两维。`;}
    #|const rows=D.rows||[];table($('rows').closest('table'),rows,true);
    #|function geometry(points,edges){const svg=$('geometry');svg.hidden=false;svg.replaceChildren();if(!points?.length)return;const xx=points.map(p=>p[0]),yy=points.map(p=>p[1]||0),xmin=Math.min(...xx),ymin=Math.min(...yy),span=Math.max(Math.max(...xx)-xmin,Math.max(...yy)-ymin)||1,xy=i=>[40+(points[i][0]-xmin)/span*540,350-((points[i][1]||0)-ymin)/span*300];for(const [a,b]of edges||[]){const x=xy(a),y=xy(b);svg.append(node('line',{x1:x[0],y1:x[1],x2:y[0],y2:y[1],stroke:'#fb923c','stroke-width':3}));}for(let i=0;i<points.length;i++){const p=xy(i);svg.append(node('circle',{cx:p[0],cy:p[1],r:3,fill:'#38bdf8'}));}}
    #|function poreView(){const [w,h,d]=D.shape_xyz,z=Number($('slice').value),label=Number($('pore-label').value),svg=$('chart');svg.replaceChildren();svg.setAttribute('viewBox',`0 0 ${w*18+20} ${h*18+40}`);for(let y=0;y<h;y++)for(let x=0;x<w;x++){const value=D.labels[(z*h+y)*w+x],active=value>0&&(!label||value===label);svg.append(node('rect',{x:10+x*18,y:20+y*18,width:17,height:17,fill:active?'#2dd4bf':value?'#475569':'#17253b'}));}const faces=[],yaw=Number($('angle').value)*Math.PI/180,pitch=Number($('tilt').value)*Math.PI/180;const project=(x,y,z)=>{x=(D.origin[0]+x*D.spacing[0])-(D.origin[0]+(w-1)*D.spacing[0]/2);y=(D.origin[1]+y*D.spacing[1])-(D.origin[1]+(h-1)*D.spacing[1]/2);z=(D.origin[2]+z*D.spacing[2])-(D.origin[2]+(d-1)*D.spacing[2]/2);const a=x*Math.cos(yaw)+z*Math.sin(yaw),b=-x*Math.sin(yaw)+z*Math.cos(yaw);return [a,y*Math.cos(pitch)-b*Math.sin(pitch),y*Math.sin(pitch)+b*Math.cos(pitch)];};const corners=[[[-.5,-.5,-.5],[-.5,-.5,.5],[-.5,.5,.5],[-.5,.5,-.5]],[[.5,-.5,-.5],[.5,.5,-.5],[.5,.5,.5],[.5,-.5,.5]],[[-.5,-.5,-.5],[.5,-.5,-.5],[.5,-.5,.5],[-.5,-.5,.5]],[[-.5,.5,-.5],[-.5,.5,.5],[.5,.5,.5],[.5,.5,-.5]],[[-.5,-.5,-.5],[-.5,.5,-.5],[.5,.5,-.5],[.5,-.5,-.5]],[[-.5,-.5,.5],[.5,-.5,.5],[.5,.5,.5],[-.5,.5,.5]]];let truncated=false;for(let i=0;i<D.labels.length;i++){const v=D.labels[i];if(!v||(label&&v!==label))continue;const x=i%w,y=Math.floor(i/w)%h,z=Math.floor(i/(w*h)),adj=[x?i-1:-1,x+1<w?i+1:-1,y?i-w:-1,y+1<h?i+w:-1,z?i-w*h:-1,z+1<d?i+w*h:-1];for(let a=0;a<6;a++){if(adj[a]>=0&&D.labels[adj[a]]>0)continue;if(faces.length>=5000){truncated=true;break;}faces.push(corners[a].map(c=>project(x+c[0],y+c[1],z+c[2])));}}faces.sort((a,b)=>a.reduce((v,p)=>v+p[2],0)-b.reduce((v,p)=>v+p[2],0));const span=Math.max(w*D.spacing[0],h*D.spacing[1],d*D.spacing[2])||1;const view=$('geometry');view.hidden=false;view.replaceChildren();for(const face of faces)view.append(node('polygon',{points:face.map(p=>`${320+p[0]/span*300},${200-p[1]/span*300}`).join(' '),fill:'#2dd4bf','fill-opacity':.65,stroke:'#0f766e','stroke-width':.5}));$('visual-note').textContent=`Z=${z}；显示标签 ${label||'全部'}。体积单位 ${D.unit}³，面积单位 ${D.unit}²。${truncated?'预览仅显示前 5000 个面，请用标签筛选或下载完整表面。':'此图是分割体素边界，不是 H2 出生代表面。'}`;}
    #|function choose(i){selected=i;$('detail-panel').hidden=false;const r=rows[i],detail={...r};if(detail.analysis)delete detail.analysis;if(D.kind==='signal_study'&&D.request.csv_source){const source=D.request.csv_source,ids=new Set();for(const g of r.grid_indices){const p=D.provenance[g];if(p){ids.add(p.left);ids.add(p.right);}}detail.csv_headers=source.headers;detail.original_csv_rows=[...ids].sort((a,b)=>a-b).map(i=>({original_row_index:i,csv_line:source.line_numbers[i],fields:source.rows[i]}));}$('detail').textContent=JSON.stringify(detail,null,2);$('selection-status').textContent=`已选择第 ${i+1} 条结果`;$('export-window').hidden=!r.request;if(D.kind==='signal_study'){lines([{name:'原始信号',values:D.original_values,color:'#38bdf8'}],D.original_times);const xs=D.original_times,lo=xs[0],span=xs[xs.length-1]-lo||1;$('chart').append(node('rect',{x:50+(r.start-lo)/span*900,y:20,width:(r.end-r.start)/span*900,height:230,fill:'#fb923c','fill-opacity':.15}));geometry(r.embedding_points,r.representative_edges);$('visual-note').textContent=`窗口 ${r.window_index}，原始时间 ${r.start}–${r.end}；嵌入只投影前两个坐标。网格到原始行的插值映射见 report.json 的 provenance。`;}else if(D.kind==='pores'){$('pore-label').value=String(r.label);poreView();}}
    #|$('export-window').addEventListener('click',()=>{const request=rows[selected]?.request;if(!request)return;const blob=new Blob([JSON.stringify(request,null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='window-request.json';a.click();URL.revokeObjectURL(url);});
    #|for(const field of ['features','envelopes','samples','anomaly_segments','invalid_windows','evaluation','clearance_connectivity'])if(Array.isArray(D[field])&&D[field].length){const section=document.createElement('section');section.className='panel';const h=document.createElement('h2');h.textContent=({features:'区间匹配重复率',envelopes:'重采样分位包络',samples:'样本与组内差异',anomaly_segments:'拓扑异常时间段',invalid_windows:'未分析的窗口',evaluation:'与简单方法的标注对照',clearance_connectivity:'净空尺度与贯通性'})[field];section.append(h);const wrap=document.createElement('div');wrap.className='scroll';const t=document.createElement('table');t.append(document.createElement('thead'),document.createElement('tbody'));wrap.append(t);section.append(wrap);$('extra').append(section);table(wrap,D[field]);if(D.kind==='cohort'&&field==='samples'){const label=document.createElement('label');label.textContent='查看样本坐标 ';const select=document.createElement('select');select.id='sample-case';for(const [i,s]of D.samples.entries()){const o=document.createElement('option');o.value=String(i);o.textContent=s.name;select.append(o);}select.addEventListener('change',()=>sampleView(Number(select.value)));label.append(select);section.prepend(label);}}
    #|if(D.kind==='signal_study'){lines([{name:'原始信号',values:D.original_values,color:'#38bdf8'}],D.original_times);if(rows.length)choose(0);}else if(D.kind==='cohort'){lines([{name:'A 组平均景观',values:rows.map(r=>r.mean_A),color:'#38bdf8'},{name:'B 组平均景观',values:rows.map(r=>r.mean_B),color:'#fb923c'}],rows.map(r=>r.scale));$('visual-note').textContent='有限第一层景观；条件假设、p 值及多尺度校正见表格。组内差异分数不代表因果贡献。';}else if(D.kind==='reliability'&&D.mode==='mean_band'){lines([{name:'均值',values:rows.map(r=>r.mean),color:'#38bdf8'},{name:'同时下界',values:rows.map(r=>r.lower),color:'#2dd4bf'},{name:'同时上界',values:rows.map(r=>r.upper),color:'#fb923c'}],rows.map(r=>r.scale));}else if(D.kind==='reliability'){lines([{name:'景观变化 RMS',values:rows.map(r=>r.landscape_rms_change),color:'#38bdf8'}],rows.map((_,i)=>i));}else if(D.kind==='pores'){$('pore-controls').hidden=false;$('slice').max=String(D.shape_xyz[2]-1);for(const r of rows){const o=document.createElement('option');o.value=String(r.label);o.textContent=`孔洞 ${r.label}`;$('pore-label').append(o);}for(const id of ['slice','pore-label','angle','tilt'])$(id).addEventListener('input',poreView);$('mesh-link').hidden=D.surface_faces>20000;poreView();}else{$('visual-panel').hidden=true;}
    #|</script></body></html>
  accessible_report(head + data + tail)
}

///|
/// Named files are computed before creating an output directory in the CLI.
pub fn research_files(
  report : Json,
) -> Array[(String, String)] raise TopologyError {
  let f = batch_object(report, "research report")
  let files = [
    ("report.json", report.stringify()),
    ("rows.csv", research_csv(report)),
    ("report.html", research_html(report)),
  ]
  if f.contains("request") {
    files.push(("study-request.json", required_field(f, "request").stringify()))
  }
  for
    field in [
      "features", "envelopes", "samples", "anomaly_segments", "invalid_windows",
      "evaluation", "clearance_connectivity",
    ] {
    if f.get(field) is Some(Array(_)) {
      files.push((field + ".csv", research_csv(report, field~)))
    }
  }
  if batch_string(f, "kind") == "pores" {
    files.push(
      (
        "labels.json",
        (
          {
            "shape_xyz": required_field(f, "shape_xyz"),
            "spacing": required_field(f, "spacing"),
            "origin": required_field(f, "origin"),
            "unit": required_field(f, "unit"),
            "labels": required_field(f, "labels"),
          } : Json).stringify(),
      ),
    )
    if integer_field(f, "surface_faces", 0) <= 20000 {
      files.push(("pores.obj", pore_surface_obj(report)))
    } else {
      files.push(
        (
          "mesh-status.json", "{\"exported\":false,\"reason\":\"surface exceeds 20000-face export budget\"}",
        ),
      )
    }
  }
  files
}
