import assert from 'node:assert/strict';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url),{chromium}=require('playwright'),axeFile=require.resolve('axe-core/axe.min.js');
const root=process.argv[2]||'out-research-cases';
const browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_EXECUTABLE_PATH||undefined});
try{
 for(const viewport of [{width:1280,height:900},{width:390,height:844}]){
  const page=await browser.newPage({viewport}),errors=[],network=[];page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(!/^(file:|data:|blob:)/.test(r.url()))network.push(r.url());});
  const open=async name=>{await page.goto(pathToFileURL(path.resolve(root,name,'report.html')).href);await page.locator('#summary').waitFor();assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true,`${name}: horizontal page overflow`);};
  for(const name of ['reliability','mean-band','cohort','signal','measurement','pores','pores-after','pore-compare','pores-nifti']){
   await open(name);await page.addScriptTag({path:axeFile});const violations=await page.evaluate(async()=>{const r=await axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21a','wcag21aa']}});return r.violations.map(v=>({id:v.id,nodes:v.nodes.map(n=>n.target)}));});assert.deepEqual(violations,[],name);
   await page.keyboard.press('Tab');assert.equal(await page.locator('.report-skip').evaluate(e=>document.activeElement===e),true);await page.keyboard.press('Enter');assert.equal(await page.locator('main').evaluate(e=>document.activeElement===e),true);
  }
  await open('measurement');await page.locator('#rows button').nth(4).click();assert.ok((await page.locator('#detail').textContent()).includes('source_record'));assert.ok((await page.locator('#detail').textContent()).includes('original_csv_rows'));assert.ok(await page.locator('#geometry circle').count()>0);
  const download=page.waitForEvent('download');await page.locator('#export-window').click();assert.equal((await download).suggestedFilename(),'window-request.json');
  await open('cohort');await page.locator('#sample-case').selectOption('1');assert.ok((await page.locator('#detail').textContent()).includes('A2'));assert.equal(await page.locator('#geometry line').count(),4);await page.locator('#rows button').nth(20).click();assert.ok((await page.locator('#detail').textContent()).includes('p_max_adjusted'));assert.equal(await page.locator('#geometry line').count(),4);
  await open('pores');await page.locator('#slice').fill('2');const initial=await page.locator('#geometry').innerHTML();await page.locator('#angle').fill('80');assert.notEqual(await page.locator('#geometry').innerHTML(),initial);await page.locator('#rows button').first().click();assert.equal(await page.locator('#pore-label').inputValue(),'1');assert.equal(await page.locator('#geometry polygon').count(),6);
  await page.locator('#slice').focus();await page.keyboard.press('ArrowRight');assert.equal(await page.locator('#slice').inputValue(),'3');
  assert.deepEqual(errors,[]);assert.deepEqual(network,[],'reports must remain offline');await page.close();console.log(`Research report interactions, keyboard, export and axe checks passed at ${viewport.width}x${viewport.height}.`);
 }
}finally{await browser.close();}
