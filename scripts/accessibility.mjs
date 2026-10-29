import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const axeFile=require.resolve('axe-core/axe.min.js');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'moontopolens-access-'));
const run=(...args)=>JSON.parse(execFileSync(process.execPath,['_build/js/debug/build/cmd/main/main.js',...args],{encoding:'utf8',windowsHide:true,timeout:60000}));
let browser;
try {
 const folder=name=>path.join(root,name);
 run('analyze','examples/square.json','--out',folder('square'));
 run('analyze','examples/clusters.json','--out',folder('no-loop'));
 run('analyze','examples/large-circle.json','--out',folder('censored'));
 run('analyze','examples/square.json','--intervals-only','--out',folder('lean'));
 run('analyze','examples/hollow-volume.json','--out',folder('volume'));
 run('compare','examples/square.json','examples/rectangle.json','--out',folder('comparison'));
 run('sweep','examples/periodic-sweep.json','--out',folder('sweep'));
 run('sequence','examples/evolving-loop.json','--out',folder('sequence'));
 run('volume-sequence','examples/volume-evolution.json','--out',folder('volume-sequence'));
 run('batch','examples/batch-study.json','--out',folder('batch'));
 browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_EXECUTABLE_PATH || undefined});
 const files=[['square','report.html'],['no-loop','report.html'],['volume','report.html'],['volume','volume-slices.html'],['comparison','comparison.html'],['sweep','sweep.html'],['sequence','sequence.html'],['volume-sequence','volume-sequence.html'],['batch','distance-heatmap.html']];
 for(const viewport of [{width:1280,height:900},{width:390,height:844}]){
  const page=await browser.newPage({viewport});const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const press=async locator=>{await locator.focus();await page.keyboard.press('Enter');};
  for(const [folderName,file] of files){
   await page.goto(pathToFileURL(path.join(folder(folderName),file)).href);
   await page.addScriptTag({path:axeFile});
   const violations=await page.evaluate(async()=>{const r=await axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21a','wcag21aa']}});return r.violations.map(v=>({id:v.id,nodes:v.nodes.map(n=>n.target)}));});
   assert.deepEqual(violations,[],`${folderName}/${file} accessibility failures`);
   assert.equal(await page.locator('main').count(),1);
   const tree=await page.locator('main').ariaSnapshot();assert.ok(tree.includes('heading'),'screen-reader tree needs headings');
   await page.keyboard.press('Tab');assert.equal(await page.locator('.report-skip').evaluate(el=>document.activeElement===el),true);
   await page.keyboard.press('Enter');assert.equal(await page.locator('main').evaluate(el=>document.activeElement===el),true);
  }
  await page.goto(pathToFileURL(path.join(folder('square'),'report.html')).href);
  await press(page.locator('#lesson-start'));assert.equal(await page.locator('#lesson-body').isVisible(),true);
  assert.equal(await page.locator('#lesson-heading').evaluate(el=>el===document.activeElement),true);
  await page.keyboard.press('Tab');assert.equal(await page.locator('#lesson-next').evaluate(el=>el===document.activeElement),true);
  await page.keyboard.press('Enter');assert.ok((await page.locator('#lesson-heading').textContent()).includes('2 / 5'));
  await press(page.locator('#lesson-next'));assert.equal(await page.locator('#h1').textContent(),'1');
  await press(page.locator('#lesson-yes'));assert.ok((await page.locator('#lesson-answer').textContent()).includes('回答正确'));
  await press(page.locator('#lesson-next'));assert.equal(await page.locator('#h1').textContent(),'0');
  await press(page.locator('#lesson-no'));assert.ok((await page.locator('#lesson-answer').textContent()).includes('回答正确'));
  await press(page.locator('#lesson-next'));assert.equal(await page.locator('#lesson-next').isDisabled(),true);
  await press(page.locator('#lesson-exit'));assert.equal(await page.locator('#lesson-start').evaluate(el=>el===document.activeElement),true);
  await press(page.locator('#interval-table button').first());assert.equal(await page.locator('#interval-table button[aria-pressed=true]').evaluate(el=>el===document.activeElement),true);
  const scale=page.locator('#scale');await scale.focus();const before=await scale.inputValue();await page.keyboard.press('ArrowRight');assert.notEqual(await scale.inputValue(),before);
  assert.ok((await page.locator('#accessible-summary').getAttribute('aria-live'))==='polite');
  await page.locator('#dimension').selectOption('0');await page.locator('#minimum').fill('0');await page.locator('#alive-only').check();
  await page.goto(pathToFileURL(path.join(folder('no-loop'),'report.html')).href);await press(page.locator('#lesson-start'));await press(page.locator('#lesson-next'));await press(page.locator('#lesson-next'));assert.ok((await page.locator('#lesson-description').textContent()).includes('未检出'));
  for(const name of ['censored','lean']){await page.goto(pathToFileURL(path.join(folder(name),'report.html')).href);await press(page.locator('#lesson-start'));for(let i=0;i<3;i++)await press(page.locator('#lesson-next'));assert.ok((await page.locator('#lesson-description').textContent()).includes(name==='censored'?'截止处仍存活':'死亡尺度'));if(name==='lean')assert.equal(await page.locator('#interval-table button:not([disabled])').count(),0);}
  assert.deepEqual(errors,[]);await page.close();console.log(`Keyboard, screen-reader semantics and axe WCAG checks passed at ${viewport.width}x${viewport.height} for ${files.length} reports.`);
 }
} finally {if(browser)await browser.close();fs.rmSync(root,{recursive:true,force:true});}
