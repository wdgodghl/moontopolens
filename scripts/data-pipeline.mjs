import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=fs.mkdtempSync(path.join(os.tmpdir(),'moontopolens-data-'));
const cli='_build/js/debug/build/cmd/main/main.js';
function run(args,code=0){const r=spawnSync(process.execPath,[cli,...args],{encoding:'utf8',windowsHide:true,timeout:60000});assert.equal(r.error,undefined);assert.equal(r.status,code,r.stderr);return code?null:JSON.parse(r.stdout);}
try {
  const input=path.join(root,'labels.csv'), out=path.join(root,'report');
  fs.writeFileSync(input,'label,x,y,constant\na,0,0,7\nb,2,0,7\nc,2,2,7\nd,0,2,7\n');
  assert.deepEqual(run(['csv-preview',input,'--columns','y,x']).headers,['y','x']);
  const report=run(['csv-points',input,'2','--columns','y,x,constant','--normalize','minmax','--out',out]);
  assert.equal(report.vertex_count,4);
  const request=JSON.parse(fs.readFileSync(path.join(out,'csv-request.json')));
  assert.deepEqual(request.points,[[0,0,0],[0,1,0],[1,1,0],[1,0,0]]);
  const info=JSON.parse(fs.readFileSync(path.join(out,'csv-info.json')));
  assert.deepEqual(info.offsets,[0,0,7]);assert.deepEqual(info.scales,[2,2,1]);assert.deepEqual(info.data_row_indices,[0,1,2,3]);
  assert.deepEqual(run(['analyze',path.join(out,'csv-request.json')]).intervals,report.intervals);
  for(const args of [[],['--columns','missing'],['--columns','x,x'],['--columns','x','--normalize','bad'],['--columns','x','--columns','y']])run(['csv-points',input,'2',...args],2);
  const ring=n=>Array.from({length:n},(_,i)=>[Math.cos(i*2*Math.PI/n),Math.sin(i*2*Math.PI/n)]);
  const ringFile=path.join(root,'ring.json');fs.writeFileSync(ringFile,JSON.stringify({kind:'points',threshold:2,points:ring(16)}));
  const exact=run(['analyze',ringFile]);
  const identity=run(['points-sample',ringFile,'16']);assert.deepEqual(identity.intervals,exact.intervals);assert.equal(identity.source.sampling.approximate,false);
  const sampledOut=path.join(root,'sampled');const sampled=run(['points-sample',ringFile,'8','--out',sampledOut]);
  const difference=run(['compare',ringFile,path.join(sampledOut,'sample-request.json')]);
  assert.equal(sampled.source.sampling.approximate,true);assert.ok(difference.distances.every(d=>d.bottleneck!==null));
  const full=JSON.parse(fs.readFileSync(ringFile));const chosen=JSON.parse(fs.readFileSync(path.join(sampledOut,'sample-request.json')));
  assert.deepEqual(chosen.points,sampled.source.sampling.source_indices.map(i=>full.points[i]));
  const large=path.join(root,'large.csv');fs.writeFileSync(large,'id,x,y\n'+ring(512).map((p,i)=>`row${i},${p.join(',')}`).join('\n'));
  const largeOut=path.join(root,'large-report');const largeReport=run(['csv-points',large,'0.3','--columns','x,y','--sample','32','--out',largeOut]);
  assert.equal(largeReport.vertex_count,32);assert.equal(largeReport.source.sampling.source_count,512);
  const meta=JSON.parse(fs.readFileSync(path.join(largeOut,'csv-info.json')));assert.deepEqual(meta.data_row_indices,largeReport.source.sampling.source_indices);assert.equal(meta.selected_raw_rows.length,32);
  run(['points-sample',ringFile,'129'],2);run(['csv-series',input,'2','2','1','1','--columns','x','--sample','2'],2);
  const manifest=path.join(root,'study.json');fs.writeFileSync(manifest,JSON.stringify({cases:[{name:'full',input:'ring.json'},{name:'copy',input:'ring.json'},{name:'sampled',input:'sampled/sample-request.json'}],comparisons:[]}));
  const studyOut=path.join(root,'study');run(['batch',manifest,'--out',studyOut,'--features','1','0','2']);
  const features=JSON.parse(fs.readFileSync(path.join(studyOut,'features.json')));
  const rows=fs.readFileSync(path.join(studyOut,'features.csv'),'utf8').trim().split('\n').map(line=>line.split(','));
  assert.deepEqual(rows[0],features.columns);assert.ok(rows.every(row=>row.length===features.columns.length));
  assert.deepEqual(features.rows[0].landscape_vector,features.rows[1].landscape_vector);
  assert.deepEqual(features.rows[0].landscape_vector,run(['landscape',ringFile,'1','0','2']).vector);
  assert.equal(features.rows[0].finite_persistence_entropy,0);assert.equal(features.rows[0].betti_at_end,0);
  assert.equal(features.rows[0].betti_vector[50],1);assert.equal(features.rows[0].censored_intervals_excluded,0);
  const h0out=path.join(root,'h0-study');run(['batch',manifest,'--out',h0out,'--features','0','0','2']);
  assert.equal(JSON.parse(fs.readFileSync(path.join(h0out,'features.json'))).rows[0].censored_intervals_excluded,1);
  for(const args of [['2','0','2'],['1','0','3'],['1','2','0']]){const bad=path.join(root,'bad-features');run(['batch',manifest,'--out',bad,'--features',...args],2);assert.equal(fs.existsSync(bad),false);}
  console.log(JSON.stringify({sampling_validation:{source_points:16,sampled_points:8,diagram_distances:difference.distances.map(d=>({dimension:d.dimension,bottleneck:d.bottleneck})),covering_radius:sampled.source.sampling.covering_radius,large_source_points:512,large_sample_points:32}}));
  console.log('CSV column selection, affine parameters, replay and error paths passed.');
} finally {fs.rmSync(root,{recursive:true,force:true});}

