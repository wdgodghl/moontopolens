import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const root = process.argv[2] || 'out-application-cases';
const cli = '_build/js/debug/build/cmd/main/main.js';
if (!fs.existsSync(cli)) throw new Error('Run moon build --target js first.');
if (fs.existsSync(root)) throw new Error('Choose a new output directory.');
fs.mkdirSync(root);
function run(...args) {
  return JSON.parse(execFileSync('node', [cli, ...args], { encoding: 'utf8', timeout: 60000, windowsHide: true }));
}
const subsetOut = path.join(root, 'iris-subset');
const subset = run('csv-points', 'examples/iris/subset.csv', '1.2', '--out', subsetOut);
assert.equal(subset.vertex_count, 36);
const slices = [0.5, 1.2].map(scale => run('slice', path.join(subsetOut, 'csv-request.json'), String(scale)));
assert.deepEqual(slices.map(s=>[s.h0,s.h1]), [[18,0],[2,0]]);
const groups = {};
for (const name of ['setosa','versicolor','virginica']) {
  const out = path.join(root, name);
  const report = run('csv-points', `examples/iris/${name}.csv`, '1.2', '--out', out);
  assert.equal(report.vertex_count, 12);
  groups[name] = report.summary;
}
const comparison = run('compare', path.join(root,'setosa','csv-request.json'), path.join(root,'versicolor','csv-request.json'), '--out', path.join(root,'species-comparison'));
assert.equal(comparison.cutoffs_equal, true);
assert.ok(Math.abs(comparison.distances[0].bottleneck - 0.41231056256176607) < 1e-10);
assert.ok(Math.abs(comparison.distances[1].bottleneck - 0.042647209597606595) < 1e-10);
const signal = run('csv-series', 'examples/periodic-series.csv', '2', '2', '1', '1', '--out', path.join(root, 'signal-reference'));
assert.equal(signal.summary[1].finite_count, 1);
const result = { iris_rows:36, slices:slices.map(s=>({scale:s.scale,h0:s.h0,h1:s.h1})), species_summaries:groups, species_distances:comparison.distances.map(d=>({dimension:d.dimension,bottleneck:d.bottleneck})), signal_summary:signal.summary };
fs.writeFileSync(path.join(root,'case-results.json'), JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));
