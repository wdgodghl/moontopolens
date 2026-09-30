import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { verifyReportUI, verifyComparisonUI } from './report-ui-smoke.mjs';

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
for (const [left,right] of [['square','square'],['square','rectangle'],['clusters','square']]) {
  const output = path.join(temporary, `compare-${left}-${right}`);
  const report = JSON.parse(cli(['compare',`examples/${left}.json`,`examples/${right}.json`,'--out',output]));
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output,'comparison.json'),'utf8')),report);
  verifyComparisonUI(fs.readFileSync(path.join(output,'comparison.html'),'utf8'),report);
  const rows = fs.readFileSync(path.join(output,'matches.csv'),'utf8').trim().split('\n');
  assert.equal(rows.length,1+report.distances.reduce((n,d)=>n+d.matches.length,0));
  let row = 1;
  for (const d of report.distances) {
    for (const m of d.matches) {
      assert.deepEqual(rows[row++].split(','),[String(d.dimension),m.left===null?'':String(m.left.index),m.right===null?'':String(m.right.index),m.kind,m.cost===null?'':String(m.cost)]);
    }
    if(d.bottleneck!==null) assert.equal(Math.max(0,...d.matches.map(m=>m.cost)),d.bottleneck);
  }
  for (const file of ['left-diagram.svg','right-diagram.svg']) assert.ok(fs.readFileSync(path.join(output,file),'utf8').startsWith('<svg'));
  cli(['compare',`examples/${left}.json`,`examples/${right}.json`,'--out',output],2);
}
const square = JSON.parse(cli(['analyze','examples/square.json']));
const loopIndex = square.intervals.findIndex(i=>i.dimension===1);
const sliceOutput = path.join(temporary,'slice-square');
const slice = JSON.parse(cli(['slice','examples/square.json','1','--out',sliceOutput,'--interval',String(loopIndex)]));
assert.equal(slice.h1,1);
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(sliceOutput,'slice.json'),'utf8')),slice);
const svg = fs.readFileSync(path.join(sliceOutput,'slice.svg'),'utf8');
assert.ok(svg.includes('stroke="#fb923c"') && !/NaN|Infinity/.test(svg));
cli(['slice','examples/square.json','1','--out',sliceOutput],2);
const matrixOutput = path.join(temporary,'slice-matrix');
cli(['slice','examples/matrix.json','0','--out',matrixOutput]);
assert.ok(!fs.existsSync(path.join(matrixOutput,'slice.svg')));
for (const [scale,index] of [['2',String(loopIndex)],['1','-1'],['1','0.5'],['1','9999']]) {
  const invalidOut = path.join(temporary,`invalid-slice-${scale}-${index}`);
  cli(['slice','examples/square.json',scale,'--out',invalidOut,'--interval',index],2);
  assert.ok(!fs.existsSync(invalidOut));
}
cli(['compare','examples/square.json','examples/square.json','--bad','unused'],2);
const imageOut = path.join(temporary, 'ring-image');
const image = JSON.parse(cli(['image', 'examples/ring-image.pgm', '1', '--out', imageOut]));
const grid = JSON.parse(cli(['analyze', 'examples/ring-grid.json']));
assert.deepEqual(image.intervals, grid.intervals);
assert.equal(betti(image, 1, 0), 1);
assert.equal(betti(image, 1, 1), 0);
assert.equal(JSON.parse(fs.readFileSync(path.join(imageOut, 'image-info.json'), 'utf8')).max_value, 1);
assert.ok(fs.readFileSync(path.join(imageOut, 'report.html'), 'utf8').includes('<html'));
const autoOut = path.join(temporary, 'bright-ring');
const automatic = JSON.parse(cli(['image', 'examples/bright-ring.pgm', 'auto', '--invert', '--out', autoOut]));
assert.equal(automatic.cutoff, 0);
assert.equal(betti(automatic, 1, 0), 1);
const autoInfo = JSON.parse(fs.readFileSync(path.join(autoOut, 'image-info.json'), 'utf8'));
assert.equal(autoInfo.cutoff_mode, 'auto_otsu');
assert.equal(autoInfo.inverted, true);
assert.equal(autoInfo.max_value, 255);
const autoWithoutOutput = JSON.parse(cli(['image', 'examples/bright-ring.pgm', 'auto', '--invert']));
assert.deepEqual(autoWithoutOutput.intervals, automatic.intervals);
assert.deepEqual(JSON.parse(cli(['image', 'examples/bright-ring.pgm', '0', '--invert'])).intervals, automatic.intervals);
const unchangedBright = JSON.parse(cli(['image', 'examples/bright-ring.pgm', 'auto']));
assert.notDeepEqual(unchangedBright.intervals, automatic.intervals);
cli(['image', 'examples/ring-image.pgm', '1', '--out', imageOut], 2);
const rawPgm = path.join(temporary, 'raw.pgm');
fs.writeFileSync(rawPgm, Buffer.from('P5\n2 1\n1023\n\x00\x01\x03\xff', 'latin1'));
const rawReport = JSON.parse(cli(['image', rawPgm, '1023']));
assert.equal(rawReport.vertex_count, 2);
const malformedPgm = path.join(temporary, 'malformed.pgm');
fs.writeFileSync(malformedPgm, 'P2 1 1 1 2');
cli(['image', malformedPgm, '1'], 2);
cli(['image', 'examples/ring-image.pgm', 'null'], 2);
cli(['image', 'examples/bright-ring.pgm', 'auto', '--out', path.join(temporary, 'bad-auto'), '--invert'], 2);
const batchOut = path.join(temporary, 'batch');
const batch = JSON.parse(cli(['batch', 'examples/batch-study.json', '--out', batchOut]));
assert.equal(batch.case_count, 6);
assert.equal(batch.comparison_count, 3);
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(batchOut, 'batch.json'), 'utf8')), batch);
for (const item of batch.cases) {
  const report = JSON.parse(fs.readFileSync(path.join(batchOut, item.report), 'utf8'));
  assert.equal(report.schema_version, 1);
  assert.ok(fs.existsSync(path.join(batchOut, 'cases', item.name, 'report.html')));
}
for (const item of batch.comparisons) {
  const report = JSON.parse(fs.readFileSync(path.join(batchOut, item.report), 'utf8'));
  assert.equal(report.distances.length, 2);
  assert.ok(fs.existsSync(path.join(batchOut, 'comparisons', item.name, 'matches.csv')));
}
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(batchOut, 'cases', 'ring-image', 'report.json'), 'utf8')).intervals, image.intervals);
assert.ok(JSON.parse(fs.readFileSync(path.join(batchOut, 'comparisons', 'image-vs-grid', 'comparison.json'), 'utf8')).distances.every(x => x.bottleneck === 0));
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(batchOut, 'cases', 'bright-ring', 'report.json'), 'utf8')).intervals, automatic.intervals);
assert.ok(JSON.parse(fs.readFileSync(path.join(batchOut, 'comparisons', 'bright-vs-grid', 'comparison.json'), 'utf8')).distances.every(x => x.bottleneck === 0));
cli(['batch', 'examples/batch-study.json', '--out', batchOut], 2);
const badManifest = path.join(temporary, 'bad-manifest.json');
fs.writeFileSync(badManifest, JSON.stringify({cases:[{name:'escape',input:'../outside.json'}]}));
const rejectedOut = path.join(temporary, 'rejected-batch');
cli(['batch', badManifest, '--out', rejectedOut], 2);
assert.ok(!fs.existsSync(rejectedOut));
cli(['batch', 'examples/batch-study.json'], 2);
cli(['slice','examples/square.json','1','--bad','unused'],2);
cli(['analyze', path.join(temporary, 'missing.json')], 2);
cli(['compare'], 2);
cli(['summary'], 2);
cli(['unknown'], 2);
assert.ok(cli(['--help']).includes('MoonTopoLens'));
console.log('CLI smoke passed: eight data scenarios, P2/P5 image import, Otsu and inversion, batch study, exact events, snapshot SVG, landscapes, comparison matching, both offline UIs, exports and errors.');
