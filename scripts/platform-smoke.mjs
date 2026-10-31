import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {gzipSync} from 'node:zlib';
import {checkReport} from './check-report.mjs';
import {validateResult} from './validate-result.mjs';
const root=fs.mkdtempSync(path.join(os.tmpdir(),'moontopolens 跨平台 ')),cli=path.resolve('_build/js/debug/build/cmd/main/main.js');
function run(args,status=0){const r=spawnSync(process.execPath,[cli,...args],{encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:32*1024*1024});assert.equal(r.error,undefined);assert.equal(r.status,status,r.stderr);return status?r:JSON.parse(r.stdout);}
try{
 const input=path.join(root,'输入 数据.csv');fs.writeFileSync(input,'id,x,y\r\na,0,0\r\nb,1,0\r\nc,1,1\r\nd,0,1\r\n');const out=path.join(root,'报告 文件');const a=validateResult(run(['csv-points',input,'2','--columns','x,y','--out',out]));assert.equal(a.vertex_count,4);checkReport(out);
 const b=validateResult(run(['analyze',path.join(out,'csv-request.json')]));assert.deepEqual(a.intervals,b.intervals);
 const old=fs.readFileSync(path.join(out,'report.json'));assert.ok(run(['analyze','examples/square.json','--out',out],2).stderr.includes('[EEXIST]'));assert.deepEqual(fs.readFileSync(path.join(out,'report.json')),old);
 assert.ok(run(['analyze',path.join(root,'missing.json')],2).stderr.includes('[ENOENT]'));
 const empty=path.join(root,'empty.json');fs.writeFileSync(empty,'');assert.ok(run(['analyze',empty],2).stderr.includes('[EMPTY_INPUT]'));
 const bad=path.join(root,'bad.json');fs.writeFileSync(bad,'{"kind":');const failed=path.join(root,'failed');assert.ok(run(['analyze',bad,'--out',failed],2).stderr.includes('invalid JSON'));assert.equal(fs.existsSync(failed),false);
 const enormous=path.join(root,'big.json');fs.writeFileSync(enormous,' '.repeat(1000001));assert.ok(run(['analyze',enormous],2).stderr.includes('[INPUT_TOO_LARGE]'));
 const zipped=path.join(root,'large.nii.gz');fs.writeFileSync(zipped,gzipSync(Buffer.alloc(1000001)));assert.ok(run(['volume',zipped,'1'],2).stderr.includes('[INVALID_GZIP]'));
 const unknown=spawnSync(process.execPath,[cli,'unrecognized','--help'],{encoding:'utf8',windowsHide:true});assert.equal(unknown.status,2);
 assert.deepEqual(fs.readdirSync(root).filter(p=>p.startsWith('.moontopolens-')),[]);
 console.log(`Platform IO, CRLF, Unicode and space paths, report replay, protection and failure checks passed: ${process.platform}.`);
}finally{fs.rmSync(root,{recursive:true,force:true});}
