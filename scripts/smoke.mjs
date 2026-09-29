import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { verifyReportUI } from './report-ui-smoke.mjs';

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'moontopolens-smoke-'));
function cli(args, code = 0) {
  const result = spawnSync('moon', ['run', '--target', 'js', 'cmd/main', '--', ...args], {
    encoding: 'utf8', timeout: 60000, windowsHide: true,
  });
  assert.equal(result.error, undefined);
  assert.equal(result.status, code, `${args.join(' ')}\n${result.stderr}`);
  return result.stdout;
}
function betti(report, dimension, scale) {
  return report.intervals.filter(i => i.dimension === dimension && i.birth <= scale && (i.death === null || scale < i.death)).length;
}
for (const name of ['square', 'rectangle', 'clusters', 'ring-grid', 'two-holes-grid', 'periodic-series', 'matrix', 'short-loop-grid']) {
  const output = path.join(temporary, name);
  const report = JSON.parse(cli(['analyze', `examples/${name}.json`, '--out', output]));
  assert.equal(report.schema_version, 1);
  assert.equal(report.summary.length, 2);
  const concise = JSON.parse(cli(['summary', `examples/${name}.json`]));
  assert.deepEqual(concise.summary, report.summary);
  assert.equal(concise.cutoff, report.cutoff);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output, 'report.json'), 'utf8')), report);
  for (const svg of ['barcode.svg', 'diagram.svg']) {
    const text = fs.readFileSync(path.join(output, svg), 'utf8');
    assert.ok(text.startsWith('<svg') && text.endsWith('</svg>'));
    assert.ok(!/NaN|Infinity/.test(text));
  }
  const intervals = fs.readFileSync(path.join(output, 'intervals.csv'), 'utf8').trim().split('\n');
  assert.equal(intervals.length, report.intervals.length + 1);
  const curve = fs.readFileSync(path.join(output, 'betti.csv'), 'utf8').trim().split('\n');
  assert.equal(curve.length, 102);
  const events = fs.readFileSync(path.join(output, 'betti-events.csv'), 'utf8').trim().split('\n');
  assert.equal(events.length, report.betti_events.length + 1);
  for (let i = 0; i < report.betti_events.length; i++) {
    const event = report.betti_events[i];
    assert.deepEqual(events[i + 1].split(',').map(Number), [event.scale, event.h0, event.h1]);
    assert.equal(event.h0, betti(report, 0, event.scale));
    assert.equal(event.h1, betti(report, 1, event.scale));
    if (i) assert.ok(event.scale > report.betti_events[i - 1].scale);
    const snapshot = JSON.parse(cli(['slice', `examples/${name}.json`, String(event.scale)]));
    assert.equal(snapshot.components.length, event.h0);
    assert.equal(snapshot.h0, event.h0);
    assert.equal(snapshot.h1, event.h1);
    const vertices = report.cells.filter(c => c.dimension === 0 && c.value <= event.scale).map(c => c.vertices[0]).sort((a,b)=>a-b);
    assert.deepEqual(snapshot.components.flat().sort((a,b)=>a-b), vertices);
    assert.ok(snapshot.components.every(group => group.length > 0 && group.every((v,j) => !j || v > group[j - 1])));
  }
  verifyReportUI(fs.readFileSync(path.join(output, 'report.html'), 'utf8'), report, name);
  if (name === 'square') {
    assert.equal(betti(report, 1, 1), 1);
    assert.equal(betti(report, 1, Math.SQRT2), 0);
  }
  if (name === 'clusters') assert.equal(betti(report, 0, 0.5), 2);
  if (name === 'ring-grid') {
    assert.equal(betti(report, 1, 0), 1);
    assert.equal(betti(report, 1, 1), 0);
  }
  if (name === 'periodic-series') assert.equal(betti(report, 1, 1.5), 1);
  if (name === 'short-loop-grid') {
    assert.equal(betti(report, 1, 0.004), 1);
    assert.equal(betti(report, 1, 0.005), 0);
    assert.ok(curve.slice(1).every(row => Number(row.split(',')[2]) === 0));
  }
  cli(['analyze', `examples/${name}.json`, '--out', output], 2);
}
const landscapeOut = path.join(temporary, 'landscape');
const landscape = JSON.parse(cli(['landscape', 'examples/two-holes-grid.json', '1', '0', '1', '--out', landscapeOut]));
assert.equal(landscape.vector.length, 303);
assert.equal(landscape.censored_intervals_excluded, 0);
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(landscapeOut, 'landscape.json'), 'utf8')), landscape);
const landscapeRows = fs.readFileSync(path.join(landscapeOut, 'landscape.csv'), 'utf8').trim().split('\n');
assert.equal(landscapeRows.length, 102);
for (let i = 0; i < 101; i++) {
  const height = Math.max(0, Math.min(landscape.grid[i], 1 - landscape.grid[i]));
  assert.deepEqual(landscapeRows[i + 1].split(',').map(Number), [landscape.grid[i], height, height, 0]);
  assert.equal(landscape.values[0][i], height);
  assert.equal(landscape.values[1][i], height);
  assert.equal(landscape.values[2][i], 0);
}
assert.deepEqual(landscape.vector, landscape.values.flat());
cli(['landscape', 'examples/two-holes-grid.json', '1', '0', '1', '--out', landscapeOut], 2);
cli(['landscape', 'examples/square.json', '2', '0', '1'], 2);
cli(['landscape', 'examples/square.json', '1', '1', '0'], 2);
cli(['landscape', 'examples/square.json', '1', 'oops', '1'], 2);
cli(['landscape'], 2);
cli(['slice', 'examples/square.json', '999'], 2);
cli(['slice', 'examples/square.json', 'null'], 2);
cli(['slice'], 2);
const same = JSON.parse(cli(['compare', 'examples/square.json', 'examples/square.json']));
assert.ok(same.distances.every(x => x.bottleneck === 0));
const changed = JSON.parse(cli(['compare', 'examples/square.json', 'examples/rectangle.json']));
assert.ok(changed.distances.find(x => x.dimension === 1).bottleneck > 0);
assert.equal(changed.cutoffs_equal, false);
cli(['analyze', path.join(temporary, 'missing.json')], 2);
cli(['compare'], 2);
cli(['summary'], 2);
cli(['unknown'], 2);
assert.ok(cli(['--help']).includes('MoonTopoLens'));
console.log('CLI smoke passed: eight scenarios, exact events, snapshots, landscapes, HTML interactions, CSV exports, comparisons and errors.');
