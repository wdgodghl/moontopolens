import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
const version='0.20.8',module='wdgodghl/moontopolens',root=fs.mkdtempSync(path.join(os.tmpdir(),'moontopolens-registry-'));
function moon(args){const result=execFileSync('moon',args,{cwd:root,encoding:'utf8',windowsHide:true,timeout:300000,maxBuffer:16*1024*1024});process.stdout.write(result);return result;}
try{
 fs.writeFileSync(path.join(root,'moon.mod'),'name = "verification/registry0208"\nversion = "0.1.0"\nlicense = "MIT"\npreferred_target = "js"\n');
 fs.writeFileSync(path.join(root,'moon.pkg'),'import {\n  "wdgodghl/moontopolens" @topo,\n} for "test"\n');
 fs.writeFileSync(path.join(root,'registry_test.mbt'),String.raw`///|
test "registry 0.20.8 H0 components and finite intervals" {
  let result=@topo.analyze_json("{\"kind\":\"points\",\"threshold\":2,\"points\":[[0,0],[1,0],[1,1],[0,1]]}")
  assert_eq(@topo.project_version(),"0.20.8")
  assert_eq(@topo.betti(result,0,0.0),4)
  assert_eq(@topo.betti(result,0,1.0),1)
  let bars=@topo.diagram(result,0)
  assert_eq(bars.length(),3)
  for bar in bars {assert_eq(bar.0,0.0);assert_eq(bar.1,1.0)}
}

///|
test "registry 0.20.8 square H1 birth death and replay" {
  let request="{\"kind\":\"points\",\"threshold\":2,\"points\":[[0,0],[1,0],[1,1],[0,1]]}"
  let result=@topo.analyze_json(request)
  let bars=@topo.diagram(result,1)
  assert_eq(bars.length(),1)
  assert_eq(bars[0].0,1.0)
  assert_true((bars[0].1-2.0.sqrt()).abs()<1.0e-12)
  assert_eq(@topo.betti(result,1,0.99),0)
  assert_eq(@topo.betti(result,1,1.0),1)
  assert_eq(@topo.betti(result,1,1.5),0)
  assert_eq(bars,@topo.diagram(@topo.analyze_json(request),1))
}

///|
test "registry 0.20.8 cutoff observation is not a finite H1 bar" {
  let result=@topo.analyze_json("{\"kind\":\"points\",\"threshold\":1.2,\"points\":[[0,0],[1,0],[1,1],[0,1]]}")
  assert_eq(@topo.betti(result,1,1.2),1)
  assert_eq(@topo.diagram(result,1).length(),0)
  assert_eq(result.intervals.filter(fn(i){i.dimension==1&&i.death is None}).length(),1)
  assert_true(@topo.report_json(result) is {"schema_version":1,"generator":{"name":"MoonTopoLens","version":"0.20.8",..},..})
}
`);
 // This is a registry operation in a newly created project, never a path dependency.
 moon(['add',module+'@'+version]);
 assert.ok(fs.readFileSync(path.join(root,'moon.mod'),'utf8').includes(module+'@'+version),'dependency must be pinned');
 for(const backend of ['js','wasm-gc']){const output=moon(['test','--target',backend]);assert.match(output,/Total tests: 3, passed: 3, failed: 0/);}
 const installed=path.join(root,'.mooncakes','wdgodghl','moontopolens');
 assert.ok(fs.readFileSync(path.join(installed,'moon.mod'),'utf8').includes('version = "'+version+'"'));
 assert.ok(!fs.realpathSync(installed).startsWith(fs.realpathSync(process.cwd())+path.sep),'installed module must not resolve into the repository');
 const evidence={module,version,source:'mooncakes.io',dependency:'registry; no path override',backends:['js','wasm-gc'],tests_per_backend:3,status:'passed',scope:'H0 counts and intervals; H1 birth/death and replay; cutoff censoring. Not an independent-user trial.'};
 if(process.argv[2])fs.writeFileSync(process.argv[2],JSON.stringify(evidence,null,2)+'\n',{flag:'wx'});
 console.log('Independent registry installation verified for '+module+'@'+version+'.');
}finally{fs.rmSync(root,{recursive:true,force:true});}
