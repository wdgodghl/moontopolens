import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=fs.mkdtempSync(path.join(os.tmpdir(),'moontopolens-exact-'));
const cli='_build/js/debug/build/cmd/main/main.js';
function run(args,code=0){const r=spawnSync(process.execPath,[cli,...args],{encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:32*1024*1024});assert.equal(r.error,undefined);assert.equal(r.status,code,r.stderr);return code?null:JSON.parse(r.stdout);}
const input=(name,value)=>{const p=path.join(root,name+'.json');fs.writeFileSync(p,JSON.stringify(value));return p;};
try {
 for(const n of [8,32,96,128]){
  const points=Array.from({length:n},(_,i)=>[Math.cos(i*2*Math.PI/n),Math.sin(i*2*Math.PI/n)]);
  const request={kind:'points',threshold:n<32?1.5:0.22,points,max_cells:10000};
  const full=run(['analyze',input('dense',request)]);
  const sparse=run(['analyze',input('sparse',{...request,kind:'points_sparse'})]);
  assert.deepEqual(sparse,full);
 }
 const csv=path.join(root,'line.csv');fs.writeFileSync(csv,'x\n'+Array.from({length:4096},(_,i)=>String(i)).join('\n'));
 const start=performance.now();const out=path.join(root,'large');
 const large=run(['csv-points',csv,'1','--engine','sparse','--max-cells','10000','--out',out]);
 assert.equal(large.vertex_count,4096);assert.equal(large.cell_count,8191);assert.equal(large.summary[0].alive_at_cutoff,1);assert.equal(large.summary[1].alive_at_cutoff,0);
 assert.equal(large.source.approximate,false);assert.ok(large.positions.every((p,i)=>p[0]===i));
 const saved=JSON.parse(fs.readFileSync(path.join(out,'csv-request.json')));assert.equal(saved.kind,'points_sparse');assert.equal(saved.points.length,4096);
 assert.deepEqual(run(['analyze',path.join(out,'csv-request.json'),'--intervals-only']).intervals.map(({representative,...rest})=>rest),large.intervals.map(({representative,...rest})=>rest));
 const isolated=run(['analyze',input('isolated',{kind:'points_sparse',points:Array.from({length:8192},(_,i)=>[i*2]),threshold:0,max_cells:10000,representatives:false})]);assert.equal(isolated.vertex_count,8192);assert.equal(isolated.summary[0].alive_at_cutoff,8192);
 const square=run(['analyze','examples/square.json']);const index=square.intervals.findIndex(i=>i.dimension===1);
 const shortestOut=path.join(root,'shortest');const exact=run(['shortest','examples/square.json',String(index),'--out',shortestOut]);assert.equal(exact.edge_count,4);assert.equal(exact.optimal,true);assert.deepEqual(JSON.parse(fs.readFileSync(path.join(shortestOut,'shortest.json'))),exact);
 const invalidOut=path.join(root,'invalid');run(['shortest','examples/square.json','0','--out',invalidOut],2);assert.equal(fs.existsSync(invalidOut),false);
 run(['csv-points',csv,'1','--engine','sparse','--sample','32'],2);
 run(['analyze',input('too-large',{kind:'points_sparse',threshold:0,max_cells:10000,points:Array.from({length:8193},(_,i)=>[i])})],2);
 console.log(JSON.stringify({exact_sparse:true,large_points:4096,large_cells:8191,isolated_points:8192,elapsed_with_exports_ms:performance.now()-start,shortest_edges:exact.edge_count}));
}finally{fs.rmSync(root,{recursive:true,force:true});}
