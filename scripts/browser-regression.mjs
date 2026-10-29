import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'moontopolens-browser-'));
const cli='_build/js/debug/build/cmd/main/main.js';
const run=(...args)=>JSON.parse(execFileSync(process.execPath,[cli,...args],{encoding:'utf8',windowsHide:true,timeout:60000}));
let browser;
try {
  const source=path.join(root,'labelled.csv');fs.copyFileSync('examples/labelled-loop.csv',source);
  const csvOut=path.join(root,'csv');const csv=run('csv-points',source,'2','--columns','x,y,z','--normalize','minmax','--out',csvOut);
  const shortOut=path.join(root,'short');run('analyze','examples/short-loop-grid.json','--out',shortOut);
  const sampleOut=path.join(root,'sample');run('points-sample','examples/square.json','3','--out',sampleOut);
  const seriesOut=path.join(root,'series');run('csv-series','examples/periodic-series.csv','2','2','1','1','--out',seriesOut);
  const leanOut=path.join(root,'lean');run('analyze','examples/square.json','--intervals-only','--out',leanOut);
  browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_EXECUTABLE_PATH || undefined});
  for(const viewport of [{width:1280,height:900},{width:390,height:844}]) {
    const page=await browser.newPage({viewport});const errors=[],network=[];
    page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
    page.on('request',r=>{if(!r.url().startsWith('file:')&&!r.url().startsWith('data:'))network.push(r.url());});
    const open=async folder=>{await page.goto(pathToFileURL(path.join(folder,'report.html')).href);await page.locator('#cells').waitFor();assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true,'horizontal page overflow');};
    await open(csvOut);
    assert.equal(await page.locator('#rotation-controls').isVisible(),true);
    const loop=csv.intervals.findIndex(i=>i.dimension===1);assert.ok(loop>=0);
    await page.locator(`[data-interval-index="${loop}"]`).click();assert.equal(await page.locator('#h1').textContent(),'1');
    assert.equal(await page.locator('#source-rows tr').count(),4);
    assert.ok((await page.locator('#source-rows').textContent()).includes('[2,2,2]'),'must retain pre-normalization values');
    await page.locator('#projection-mode').selectOption('3d');
    const before=await page.locator('#geometry').innerHTML();
    await page.locator('#yaw').fill('75');await page.locator('#pitch').fill('35');
    assert.notEqual(await page.locator('#geometry').innerHTML(),before,'rotation should change projected geometry');
    assert.equal(await page.locator('#geometry line[stroke="#fb923c"]').count(),4);
    await page.locator('#rotation-reset').click();assert.equal(await page.locator('#yaw').inputValue(),'0');
    assert.ok((await page.locator('#censor-note').textContent()).includes('景观不计入'));
    await open(shortOut);await page.locator('#scale-exact').fill('0.0045');assert.equal(await page.locator('#h1').textContent(),'1');
    await page.locator('#event-next').click();assert.equal(await page.locator('#h1').textContent(),'0');assert.equal(await page.locator('#scale-exact').inputValue(),'0.005');
    await page.locator('#interval-table button').first().click();assert.equal(await page.locator('#h1').textContent(),'1');assert.equal(await page.locator('#geometry line[stroke="#fb923c"]').count(),8);
    await open(sampleOut);assert.equal(await page.locator('#source-note').isVisible(),true);assert.ok((await page.locator('#source-note').textContent()).includes('近似采样分析'));
    await open(seriesOut);await page.locator('#interval-table button').first().click();assert.ok((await page.locator('#source-meaning').textContent()).includes('delay window'));assert.ok(await page.locator('#source-rows tr').count()>0);
    await open(leanOut);assert.equal(await page.locator('#source-panel').isVisible(),false);assert.equal(await page.locator('#interval-table button:not([disabled])').count(),0);
    assert.deepEqual(errors,[]);assert.deepEqual(network,[],'offline reports must not request network assets');
    await page.close();console.log(`Chromium report regression passed at ${viewport.width}x${viewport.height}.`);
  }
} finally {if(browser)await browser.close();fs.rmSync(root,{recursive:true,force:true});}
