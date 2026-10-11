import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const cli = path.join('_build', 'js', 'debug', 'build', 'cmd', 'bench', 'bench.js');
const sizes = [8, 12, 16, 20, 24, 28];
const repeats = 3;
const build = spawnSync('moon', ['build', '--target', 'js'], {
  encoding: 'utf8', timeout: 120000, windowsHide: true,
});
assert.equal(build.error, undefined);
assert.equal(build.status, 0, build.stderr);

const results = [];
for (const size of sizes) {
  const runs = [];
  for (let i = 0; i < repeats; i++) {
    const run = spawnSync('node', [cli, String(size)], {
      encoding: 'utf8', timeout: 120000, windowsHide: true,
    });
    assert.equal(run.error, undefined);
    assert.equal(run.status, 0, run.stderr);
    const result = JSON.parse(run.stdout);
    assert.equal(result.point_count, size);
    assert.ok(result.cell_count > 0 && Number.isFinite(result.elapsed_ms));
    assert.ok(Number.isFinite(result.rss_mib_after));
    runs.push(result);
  }
  const median = [...runs].sort((a, b) => a.elapsed_ms - b.elapsed_ms)[1];
  results.push({
    point_count: size,
    cell_count: median.cell_count,
    interval_count: median.interval_count,
    median_elapsed_ms: median.elapsed_ms,
    median_process_rss_mib_after: [...runs].sort((a, b) => a.rss_mib_after - b.rss_mib_after)[1].rss_mib_after,
    repeats,
  });
}
const sparseResults = [];
for (const size of [32, 64, 96, 128]) {
  const runs = [];
  for (let i = 0; i < repeats; i++) {
    const run = spawnSync('node', [cli, String(size), 'sparse'], {
      encoding: 'utf8', timeout: 120000, windowsHide: true,
    });
    assert.equal(run.error, undefined);
    assert.equal(run.status, 0, run.stderr);
    const result = JSON.parse(run.stdout);
    assert.equal(result.point_count, size);
    assert.ok(result.cell_count > size && Number.isFinite(result.elapsed_ms));
    runs.push(result);
  }
  const median = [...runs].sort((a,b) => a.elapsed_ms - b.elapsed_ms)[1];
  sparseResults.push({point_count:size,cell_count:median.cell_count,interval_count:median.interval_count,median_elapsed_ms:median.elapsed_ms,median_process_rss_mib_after:[...runs].sort((a,b)=>a.rss_mib_after-b.rss_mib_after)[1].rss_mib_after,repeats});
}
console.log(JSON.stringify({
  schema_version: 1,
  benchmark: 'dense and sparse Rips H0/H1, deterministic 2D points, JS target',
  timing: 'MoonBit filtration construction and reduction only; Node startup excluded',
  memory: 'process RSS after analysis, not peak RSS; includes Node runtime',
  node: process.version,
  platform: `${process.platform}-${process.arch}`,
  results,
  sparse_results: sparseResults,
}, null, 2));
