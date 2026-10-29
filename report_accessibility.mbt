///|
/// Shared keyboard entry, landmarks, table semantics and SVG names for reports.
fn accessible_report(html : String) -> String {
  let css = "<style>.report-skip{position:absolute;left:12px;top:-100px;padding:10px;background:#fff;color:#111;z-index:100}.report-skip:focus{top:8px}:focus-visible{outline:3px solid #facc15;outline-offset:3px}button:disabled{cursor:default}[hidden]{display:none!important}</style>"
  let script =
    #|if(document.querySelectorAll){
    #| const reportMain=document.querySelector('main');if(reportMain){reportMain.id='report-main';reportMain.setAttribute('tabindex','-1');}
    #| const repair=()=>{for(const th of document.querySelectorAll('thead th'))if(!th.hasAttribute('scope'))th.setAttribute('scope','col');for(const svg of document.querySelectorAll('svg')){if(!svg.hasAttribute('role'))svg.setAttribute('role','img');if(!svg.hasAttribute('aria-label')&&!svg.hasAttribute('aria-labelledby'))svg.setAttribute('aria-label',svg.querySelector('title')?.textContent||'拓扑图表，数值与含义见相邻说明和表格');}for(const control of document.querySelectorAll('input,select'))if(!control.getAttribute('aria-label')&&!control.getAttribute('aria-labelledby')&&!control.labels?.length)control.setAttribute('aria-label',({'yaw':'水平旋转角度','pitch':'俯仰角度','minimum':'最小观察寿命','dimension':'同调维度','scale':'观察尺度'})[control.id]||control.id||'分析参数');};repair();
    #| const scrollRepair=()=>{for(const region of document.querySelectorAll('.scroll,.table-wrap,.panel'))if(region.matches('.scroll,.table-wrap')||region.scrollWidth>region.clientWidth||region.scrollHeight>region.clientHeight){region.setAttribute('tabindex','0');region.setAttribute('role','region');if(!region.hasAttribute('aria-label')&&!region.hasAttribute('aria-labelledby'))region.setAttribute('aria-label','可滚动的数据区域，使用方向键滚动');}};scrollRepair();
    #| if(typeof MutationObserver!=='undefined'&&reportMain)new MutationObserver(()=>{repair();scrollRepair();}).observe(reportMain,{childList:true,subtree:true});
    #|}
  let result = html
    .replace_all(old="</head>", new=css + "</head>")
    .replace_all(
      old="<body>",
      new="<body><a class=\"report-skip\" href=\"#report-main\">跳到报告内容</a>",
    )
  if result.contains("</script></body>") {
    result.replace_all(old="</script></body>", new=script + "</script></body>")
  } else if result.contains("</script></main>") {
    result.replace_all(old="</script></main>", new=script + "</script></main>")
  } else {
    result
    .replace_all(old="<main>", new="<main id=\"report-main\" tabindex=\"-1\">")
    .replace_all(
      old="<div class=scroll>",
      new="<div class=scroll tabindex=\"0\" role=\"region\" aria-label=\"可滚动的数据表\">",
    )
    .replace_all(old="<tr><th><a", new="<tr><th scope=\"row\"><a")
    .replace_all(old="<th>", new="<th scope=\"col\">")
  }
}
