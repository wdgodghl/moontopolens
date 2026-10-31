import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {checkReport} from './check-report.mjs';
import {validateResult} from './validate-result.mjs';
const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'moontopolens 文档 '));
const catalog=JSON.parse(fs.readFileSync('contracts/capabilities.json','utf8'));
let commands=0;
try{
 const text=fs.readFileSync('docs/first-run.md','utf8');for(const match of text.matchAll(/```sh verify\r?\n([\s\S]*?)```/g))for(const line of match[1].trim().split(/\r?\n/)){
  const tokens=line.match(/"[^"]*"|'[^']*'|\S+/g).map(t=>t.replace(/^["']|["']$/g,'').replaceAll('{OUT}',temporary));
  const executable=tokens.shift();execFileSync(executable==='node'?process.execPath:executable,tokens,{encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:32*1024*1024});commands++;
 }
 assert.ok(commands>=6,'document commands must be exercised');
 const read=name=>JSON.parse(fs.readFileSync(path.join(temporary,name),'utf8'));
 const csv=validateResult(read('csv/report.json')),again=validateResult(read('replayed/report.json')),signal=validateResult(read('signal/report.json'));
 assert.equal(csv.vertex_count,36);assert.deepEqual(csv.intervals,again.intervals);assert.deepEqual(csv.cells,again.cells);assert.equal(signal.original_values.length,128);assert.equal(signal.rows.length,15);assert.equal(signal.evaluation,null);
 for(const folder of ['csv','replayed','signal'])assert.equal(checkReport(path.join(temporary,folder)).project_version,catalog.project_version);
 for(const [command,usage]of Object.entries(catalog.commands)){const out=execFileSync(process.execPath,['_build/js/debug/build/cmd/main/main.js',command,'--help'],{encoding:'utf8',windowsHide:true});assert.ok(out.includes(usage.split('\n')[0]),command);}
 const broken=structuredClone(csv);delete broken.result_contract;assert.throws(()=>validateResult(broken));
 const changed=path.join(temporary,'csv','intervals.csv');fs.writeFileSync(changed,'manual change');assert.throws(()=>checkReport(path.join(temporary,'csv')));
 let files=['README.md','CHANGELOG.md'];const walk=d=>{for(const e of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,e.name);if(e.isDirectory())walk(p);else if(p.endsWith('.md'))files.push(p);}};walk('docs');walk('examples');
 for(const file of files){const content=fs.readFileSync(file,'utf8');let fence=false;const lines=content.split(/\r?\n/);for(let i=0;i<lines.length;i++){const l=lines[i];if(l.startsWith('```')){fence=!fence;continue;}if(fence)continue;
  if(l.startsWith('|')&&!(lines[i-1]||'').startsWith('|'))assert.match(lines[i+1]||'',/^\|(?:\s*:?-+:?\s*\|)+\s*$/,`${file}:${i+1}: table separator must follow header`);
  for(const m of l.matchAll(/\[[^\]]*\]\(([^\s)]+)\)/g)){const url=m[1];if(/^(https?:|mailto:|#)/.test(url))continue;const local=decodeURIComponent(url.split('#')[0]);assert.ok(fs.existsSync(path.resolve(path.dirname(file),local)),`${file}: broken local link ${url}`);}
 }}
 console.log(`Verified ${commands} documented commands, ${Object.keys(catalog.commands).length} command help entries, result replay, hashes and ${files.length} Markdown files.`);
}finally{fs.rmSync(temporary,{recursive:true,force:true});}
