import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {EventEmitter} from 'node:events';
const require=createRequire(import.meta.url),source=fs.readFileSync('cmd/main/host.mbt','utf8').split('extern "js" fn initialize_host() -> Unit =')[1].split('\n').filter(l=>/^\s*#\|/.test(l)).map(l=>l.replace(/^\s*#\|/,'')).join('\n');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'moontopolens-io-'));
function runtime(override={}){const p=new EventEmitter();p.versions=process.versions;p.stderr={text:'',write(s){this.text+=s;}};const wrapped=Object.assign(Object.create(fs),override),ctx={process:p,require:n=>n==='node:fs'?wrapped:require(n),Buffer,TextDecoder};vm.createContext(ctx);vm.runInContext('('+source+')()',ctx);return {host:ctx.__moontopolensHost,p};}
function finish(r){r.p.emit('exit',r.p.exitCode||0);}
function noStages(){assert.deepEqual(fs.readdirSync(root).filter(n=>n.startsWith('.moontopolens-')),[]);}
try{
 for(const [name,code,setup]of [
  ['missing','ENOENT',()=>{}],['empty','EMPTY_INPUT',p=>fs.writeFileSync(p,'')],['directory','EISDIR',p=>fs.mkdirSync(p)],['oversize','INPUT_TOO_LARGE',p=>fs.writeFileSync(p,Buffer.alloc(1000001))],['encoding','INVALID_UTF8',p=>fs.writeFileSync(p,Buffer.from([0xff]))],
 ]){const f=path.join(root,name);setup(f);const r=runtime();assert.equal(r.host.read(f,'text'),'');r.host.error('fallback');assert.ok(r.p.stderr.text.includes('['+code+']'),r.p.stderr.text);assert.equal(r.p.exitCode,2);finish(r);}
 const boundary=path.join(root,'boundary');fs.writeFileSync(boundary,'a'.repeat(1000000));assert.equal(runtime().host.read(boundary,'text').length,1000000);
 const permission=runtime({statSync(){const e=new Error('denied');e.code='EACCES';throw e;}});permission.host.read(boundary,'text');permission.host.error('fallback');assert.ok(permission.p.stderr.text.includes('[EACCES]'));
 const gzip=path.join(root,'bad.nii.gz');fs.writeFileSync(gzip,'truncated');const bad=runtime();assert.equal(bad.host.read(gzip,'nifti').length,0);bad.host.error('fallback');assert.ok(bad.p.stderr.text.includes('[INVALID_GZIP]'));
 const dest=path.join(root,'中文 空格 report');let r=runtime();assert.equal(r.host.directory(dest),true);assert.equal(fs.existsSync(dest),false);assert.equal(r.host.write(dest,'one.txt','数据'),true);const child=path.join(dest,'cases');assert.equal(r.host.directory(child),true);assert.equal(r.host.write(child,'two.json','{}'),true);finish(r);assert.equal(r.p.exitCode,undefined,r.p.stderr.text);assert.equal(fs.readFileSync(path.join(dest,'one.txt'),'utf8'),'数据');const m=JSON.parse(fs.readFileSync(path.join(dest,'run-manifest.json'),'utf8'));assert.deepEqual(m.artifacts.map(a=>a.path),['cases/two.json','one.txt']);assert.ok(!JSON.stringify(m).includes(root));
 const keep=fs.readFileSync(path.join(dest,'one.txt'));r=runtime();assert.equal(r.host.directory(dest),false);r.host.error('fallback');finish(r);assert.deepEqual(fs.readFileSync(path.join(dest,'one.txt')),keep);
 for(const code of ['ENOSPC','EACCES','EPERM']){const failed=path.join(root,'failed-'+code);r=runtime({writeFileSync(file,...args){if(path.basename(file)==='two.txt'){const e=new Error(code);e.code=code;throw e;}return fs.writeFileSync(file,...args);}});assert.equal(r.host.directory(failed),true);assert.equal(r.host.write(failed,'one.txt','ok'),true);assert.equal(r.host.write(failed,'two.txt','bad'),false);r.host.error('fallback');finish(r);assert.equal(fs.existsSync(failed),false);assert.ok(r.p.stderr.text.includes('['+code+']'));noStages();}
 // A core error after successful writes also rolls back; no misleading final report.
 const aborted=path.join(root,'aborted');r=runtime();r.host.directory(aborted);r.host.write(aborted,'report.json','{}');r.host.error('analysis failed');finish(r);assert.equal(fs.existsSync(aborted),false);noStages();
 // Target appears after staging: preserve the other writer's result.
 const race=path.join(root,'race');r=runtime();r.host.directory(race);r.host.write(race,'x','new');fs.mkdirSync(race);fs.writeFileSync(path.join(race,'x'),'existing');finish(r);assert.equal(r.p.exitCode,2);assert.equal(fs.readFileSync(path.join(race,'x'),'utf8'),'existing');noStages();
 const promotion=path.join(root,'promotion');r=runtime({renameSync(){const e=new Error('busy');e.code='EPERM';throw e;}});r.host.directory(promotion);r.host.write(promotion,'x','ok');finish(r);assert.equal(r.p.exitCode,2);assert.equal(fs.existsSync(promotion),false);noStages();
 const outside=path.join(root,'outside');fs.writeFileSync(outside,'secret');const manifest=path.join(dest,'manifest.json');fs.writeFileSync(manifest,'{}');r=runtime();assert.equal(r.host.child(manifest,'../outside','text'),'');r.host.error('fallback');assert.ok(r.p.stderr.text.includes('[EPERM]'));
 console.log('Input classification, byte limits, permissions, disk-full rollback, promotion failure, races and Unicode output paths passed.');
}finally{fs.rmSync(root,{recursive:true,force:true});}
