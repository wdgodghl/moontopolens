import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync,spawnSync} from 'node:child_process';
const root=process.argv[2]||'out-research-cases';
if(fs.existsSync(root))throw Error('Choose a new output directory');fs.mkdirSync(root);
const cli='_build/js/debug/build/cmd/main/main.js';
const run=(...args)=>JSON.parse(execFileSync(process.execPath,[cli,...args],{encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:32*1024*1024}));
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const save=(name,value)=>{const p=path.join(root,name);fs.writeFileSync(p,JSON.stringify(value));return p;};
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-10*Math.max(1,Math.abs(b)),`${a} != ${b}`);
const square=side=>({kind:'points',threshold:2,points:[[0,0],[side,0],[side,side],[0,side]]});
const output=(name,...args)=>run(...args,'--out',path.join(root,name));
const reliability=output('reliability','reliability','examples/reliability-points.json');
assert.equal(reliability.rows.length,32);assert.equal(reliability.envelopes.length,124);
assert.deepEqual(reliability,run('reliability','examples/reliability-points.json'));
const band=output('mean-band','reliability','examples/reliability-band.json');
near(band.epsilon,Math.sqrt(Math.log(62/.05)/8));assert.equal(band.vacuous,false);
const band64=run('reliability',save('band64.json',{...read('examples/reliability-band.json'),inputs:Array.from({length:64},()=>square(1))}));
assert.equal(band64.vacuous,false);near(band64.epsilon,Math.sqrt(Math.log(62/.05)/128));
// Independent oracle: analytic square bar [s,s*sqrt(2)], no calls to MoonBit landscapes.
const cohort=output('cohort','cohort','examples/cohort-loops.json');
const sides=[1,1.1,1.2,.3,.4,.5],grid=Array.from({length:31},(_,i)=>2*i/30);
const vectors=sides.map(s=>grid.map(t=>Math.max(0,Math.min(t-s,s*Math.SQRT2-t))));
const difference=ids=>grid.map((_,j)=>vectors.reduce((v,row,i)=>v+(ids.includes(i)?row[j]/3:-row[j]/3),0));
const rms=v=>Math.hypot(...v)/Math.sqrt(v.length),observed=difference([0,1,2]),global=rms(observed);
let all=0,g=0;const raw=grid.map(()=>0),adjusted=grid.map(()=>0);
for(let a=0;a<6;a++)for(let b=a+1;b<6;b++)for(let c=b+1;c<6;c++){
 const d=difference([a,b,c]),peak=Math.max(...d.map(Math.abs));all++;
 if(rms(d)+1e-12>=global)g++;
 d.forEach((v,i)=>{if(Math.abs(v)+1e-12>=Math.abs(observed[i]))raw[i]++;if(peak+1e-12>=Math.abs(observed[i]))adjusted[i]++;});
}
near(cohort.global_p_exact,g/all);near(cohort.global_l2_rms,global);assert.equal(cohort.permutations,20);
cohort.rows.forEach((r,i)=>{near(r.effect_A_minus_B,observed[i]);near(r.p_raw,raw[i]/all);near(r.p_max_adjusted,adjusted[i]/all);});
const cf=read('examples/cohort-loops.json');cf.samples.reverse();
const reordered=run('cohort',save('reordered.json',cf));near(reordered.global_p_exact,cohort.global_p_exact);
cf.samples.forEach(s=>s.group=s.group==='A'?'B':'A');const swapped=run('cohort',save('swapped.json',cf));near(swapped.global_p_exact,cohort.global_p_exact);
swapped.rows.forEach((r,i)=>near(r.effect_A_minus_B,-cohort.rows[i].effect_A_minus_B));
const withPaths={...cf,samples:cf.samples.map((s,i)=>({name:s.name,group:s.group,input:path.basename(save(`case-${i}.json`,s.request))}))};
near(run('cohort',save('relative-cohort.json',withPaths)).global_p_exact,cohort.global_p_exact);
const signal=output('signal','signal-study','examples/signal-change.json');
assert.equal(signal.rows.length,11);assert.equal(signal.evaluation.length,4);
assert.ok(signal.rows.some(r=>r.anomaly));
for(const r of signal.rows){const replay=run('analyze',save('window.json',r.request));assert.deepEqual(replay.positions,r.embedding_points);const loops=replay.intervals.filter(t=>t.dimension===1);near(r.observed_loop_score,Math.max(0,...loops.map(t=>(t.death??replay.cutoff)-t.birth))/replay.cutoff);}
const actual=output('measurement','signal-csv','examples/beijing-pm25/signal.csv','examples/beijing-pm25/config.json');
assert.equal(actual.original_values.length,128);assert.equal(actual.rows.length,15);assert.equal(actual.evaluation,null);
assert.equal(actual.request.csv_source.rows[0][3],'25');assert.equal(actual.request.csv_source.rows.at(-1)[3],'152');
const sf=read('examples/signal-change.json');sf.times[30]+=.25;sf.values[51]=null;sf.interpolation='linear';sf.max_gap=3;
const interpolated=run('signal-study',save('interpolate.json',sf));
interpolated.provenance.forEach((p,i)=>{if(!p)return;const expected=sf.values[p.left]*(1-p.weight_right)+sf.values[p.right]*p.weight_right;near(interpolated.resampled_values[i],expected);});
const before=output('pores','pores','examples/pores-before.json');const after=output('pores-after','pores','examples/pores-after.json');
assert.equal(before.enclosed_components,2);assert.equal(before.pore_volume,48);assert.equal(after.pore_volume,72);
const changes=output('pore-compare','pore-compare','examples/pores-before.json','examples/pores-after.json');
assert.equal(changes.pore_volume_change,24);assert.equal(changes.rows.length,2);changes.rows.forEach(r=>{near(r.iou,1/3);assert.equal(r.merge_candidate,true);});
// Every clearance value against a direct closest-box oracle on the exported segmentation.
for(const report of [before,after]){
 const [w,h,d]=report.shape_xyz,xyz=i=>[i%w,Math.floor(i/w)%h,Math.floor(i/(w*h))];
 report.labels.forEach((label,i)=>{if(!label)return;let best=Infinity;report.labels.forEach((solid,j)=>{if(solid)return;const a=xyz(i),b=xyz(j);best=Math.min(best,Math.hypot(...a.map((v,k)=>Math.max(0,Math.abs(v-b[k])-.5)*report.spacing[k])));});near(report.solid_clearance[i],best);});
 const obj=fs.readFileSync(path.join(root,report===before?'pores':'pores-after','pores.obj'),'utf8'),vertices=[],triangles=[];
 for(const line of obj.split('\n')){if(line.startsWith('v '))vertices.push(line.slice(2).split(' ').map(Number));if(line.startsWith('f '))triangles.push(line.slice(2).split(' ').map(n=>Number(n)-1));}
 assert.equal(triangles.length,report.surface_faces*2);
 // Triangle area agrees with the sum of observed solid interfaces and crop caps.
 let area=0;for(const ids of triangles){const [a,b,c]=ids.map(i=>vertices[i]),u=b.map((v,i)=>v-a[i]),v=c.map((v,i)=>v-a[i]);area+=Math.hypot(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])/2;}
 near(area,report.rows.reduce((n,r)=>n+r.solid_interface_area+r.crop_cap_area,0));
}
// Generate a tiny physical NIfTI (sform), then compare with the JSON segmentation.
const source=read('examples/pores-before.json'),bytes=Buffer.alloc(352+125);bytes.writeInt32LE(348);bytes.writeInt16LE(3,40);[5,5,5,1].forEach((v,i)=>bytes.writeInt16LE(v,42+i*2));bytes.writeInt16LE(2,70);bytes.writeInt16LE(8,72);bytes.writeFloatLE(352,108);bytes[123]=3;bytes.writeInt16LE(1,254);bytes.write('n+1\0',344,'binary');
for(let i=0;i<3;i++){bytes.writeFloatLE(source.spacing[i],280+16*i+4*i);bytes.writeFloatLE(source.origin[i],280+16*i+12);}
source.volume.flat(2).forEach((v,i)=>bytes[352+i]=v);const nii=path.join(root,'pores.nii');fs.writeFileSync(nii,bytes);
const imported=output('pores-nifti','pores-nifti',nii,'examples/pores-nifti.json');assert.deepEqual(imported.labels,before.labels);assert.deepEqual(imported.spacing,before.spacing);assert.equal(imported.unit,'um');
// Invalid requests must not create an output folder or overwrite a previous report.
for(const [name,args]of [['existing',['pores','examples/pores-before.json','--out',path.join(root,'pores')]],['invalid',['cohort',save('invalid.json',{...cf,unit:''}),'--out',path.join(root,'invalid')]],['escape',['cohort',save('escape.json',{...withPaths,samples:withPaths.samples.map(s=>({...s,input:'../examples/square.json'}))}),'--out',path.join(root,'escape')]]]){
 const result=spawnSync(process.execPath,[cli,...args],{encoding:'utf8',windowsHide:true});assert.equal(result.status,2,name);if(name!=='existing')assert.equal(fs.existsSync(path.join(root,name)),false);
}
const summary={permutation_oracle:{global_p:cohort.global_p_exact,permutations:all},synthetic_signal_evaluation:signal.evaluation,measurement:{windows:actual.rows.length,anomaly_windows:actual.rows.filter(r=>r.anomaly).length,thresholds:actual.thresholds,has_event_labels:false},pores:{before_volume:before.pore_volume,after_volume:after.pore_volume,merge_links:changes.rows.length}};
fs.writeFileSync(path.join(root,'verified-results.json'),JSON.stringify(summary,null,2)+'\n');
console.log(JSON.stringify(summary,null,2));console.log('Research workflows, independent numeric oracles, provenance and failure paths passed.');


