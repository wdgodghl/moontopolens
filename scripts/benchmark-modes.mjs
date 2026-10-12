import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import os from 'node:os';

const build=spawnSync('moon',['build','--target','js'],{encoding:'utf8',windowsHide:true});
assert.equal(build.status,0,build.stderr);
const cli='_build/js/debug/build/cmd/bench/bench.js';
const repeats=3, results=[];
const median = xs => [...xs].sort((a,b)=>a-b)[1];
for(const [distribution,sizes] of [['dense',[16,24,28,38]],['sparse',[32,64,128]]]) {
  for(const size of sizes) {
    const modes={};
    for(let repeat=0;repeat<repeats;repeat++) {
      // Alternate order to reduce a fixed first-run bias. Each run is a new process.
      for(const mode of repeat%2?['intervals','full']:['full','intervals']) {
        const run=spawnSync('node',[cli,String(size),distribution,mode],{encoding:'utf8',timeout:120000,windowsHide:true});
        assert.equal(run.status,0,run.stderr);
        const value=JSON.parse(run.stdout);
        assert.equal(value.representatives_computed,mode==='full');
        (modes[mode]??=[]).push(value);
      }
    }
    for(let i=0;i<repeats;i++) assert.deepEqual(modes.full[i].diagram,modes.intervals[i].diagram);
    assert.ok(modes.intervals[0].reduction_entries < modes.full[0].reduction_entries);
    const summary = runs => ({elapsed_ms:median(runs.map(r=>r.elapsed_ms)),rss_mib_after:median(runs.map(r=>r.rss_mib_after)),peak_rss_mib:runs.every(r=>r.peak_rss_mib>0)?median(runs.map(r=>r.peak_rss_mib)):null,reduction_entries:runs[0].reduction_entries});
    results.push({distribution,point_count:size,cell_count:modes.full[0].cell_count,full:summary(modes.full),intervals:summary(modes.intervals)});
  }
}
console.log(JSON.stringify({schema_version:1,node:process.version,platform:`${process.platform}-${process.arch}`,cpu:os.cpus()[0]?.model,repeats,timing:'filtration construction and reduction; startup excluded',memory:'OS process lifetime high-water RSS via Node resourceUsage.maxRSS; includes runtime and startup, null if unavailable; not topology-only allocations',results},null,2));
