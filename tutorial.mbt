///|
fn tutorial_script() -> String {
  (
    #|let lessonStep=0;
    #|const lessonLoop=DATA.intervals.findIndex(i=>i.dimension===1),lessonTitles=['读取输入与尺度','观察连接分量合并','定位环路出生','观察死亡或截止','完成观察与测验'];
    #|function showLesson(){el('lesson-body').hidden=false;el('lesson-heading').textContent=`第 ${lessonStep+1} / 5 步：${lessonTitles[lessonStep]}`;el('lesson-previous').disabled=lessonStep===0;el('lesson-next').disabled=lessonStep===4;el('lesson-answer').textContent='';let scale=current,text='';
    #| if(lessonStep===0){selected=-1;scale=low;text=`输入有 ${DATA.vertex_count} 个顶点。先观察起始尺度的 H0 与 H1，再逐步增加尺度。H0 是连接分量数，H1 是环路数。`;}
    #| if(lessonStep===1){const initial=counts(low)[0],event=DATA.betti_events.find(p=>p.h0<initial);scale=event?.scale??low;text=event?'已跳到第一次 H0 减少的事件；观察连接分量如何合并。':'当前输入范围没有 H0 合并事件，不额外构造事件。';}
    #| if(lessonStep===2){if(lessonLoop>=0){selected=DATA.representatives_computed===false?-1:lessonLoop;scale=DATA.intervals[lessonLoop].birth;text=`区间 #${lessonLoop} 在此出生，H1 已计入该类。${DATA.representatives_computed===false?'仅区间模式没有代表链。':'观察橙色代表边，并在原始数据表中核对编号。'}`;}else{text='此输入未检出 H1 区间；本步保持实际结果，不生成示意环路。';}}
    #| if(lessonStep===3){const i=DATA.intervals[lessonLoop];scale=i?.death??DATA.cutoff;text=i?.death!==null&&i?`已跳到死亡尺度 ${i.death}。[出生,死亡) 不包含死亡端点，所选环路的橙色高亮应消失。`:i?'该环路在截止处仍存活；尚未观察到死亡，不能据此认定永久存在。':'此输入没有可追踪的 H1 环路；查看截止处的实际计数。';}
    #| if(lessonStep===4){text='结合当前尺度和顶部 H1 计数回答下方问题。可以返回上一步重新观察；测验以当前数据实际计数为准。';}
    #| renderAt(scale);el('lesson-description').textContent=text;el('lesson-heading').focus?.();}
    #|el('lesson-start').addEventListener('click',()=>{lessonStep=0;el('minimum').value='0';el('alive-only').checked=false;el('dimension').value='1';page=0;showLesson();});
    #|el('lesson-previous').addEventListener('click',()=>{if(lessonStep>0){lessonStep--;showLesson();}});el('lesson-next').addEventListener('click',()=>{if(lessonStep<4){lessonStep++;showLesson();}});
    #|el('lesson-exit').addEventListener('click',()=>{el('lesson-body').hidden=true;el('lesson-start').focus?.();});
    #|for(const [id,answer]of [['lesson-yes',true],['lesson-no',false]])el(id).addEventListener('click',()=>{const actual=counts(current)[1]>0;el('lesson-answer').textContent=answer===actual?`回答正确。当前 H1=${counts(current)[1]}，尺度为 ${current}。`:`请再观察顶部 H1：当前为 ${counts(current)[1]}。可返回步骤核对出生和死亡端点。`;});
  )
}
