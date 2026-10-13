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
  const report=run(['csv-points',input,'2','--columns','y,x,constant','--normalize','minmax','--out',out]);
  assert.equal(report.vertex_count,4);
  const request=JSON.parse(fs.readFileSync(path.join(out,'csv-request.json')));
  assert.deepEqual(request.points,[[0,0,0],[0,1,0],[1,1,0],[1,0,0]]);
  const info=JSON.parse(fs.readFileSync(path.join(out,'csv-info.json')));
  assert.deepEqual(info.offsets,[0,0,7]);assert.deepEqual(info.scales,[2,2,1]);assert.deepEqual(info.data_row_indices,[0,1,2,3]);
  assert.deepEqual(run(['analyze',path.join(out,'csv-request.json')]).intervals,report.intervals);
  for(const args of [[],['--columns','missing'],['--columns','x,x'],['--columns','x','--normalize','bad'],['--columns','x','--columns','y']])run(['csv-points',input,'2',...args],2);
  console.log('CSV column selection, affine parameters, replay and error paths passed.');
} finally {fs.rmSync(root,{recursive:true,force:true});}

