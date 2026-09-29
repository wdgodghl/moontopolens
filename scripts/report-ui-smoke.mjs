import assert from 'node:assert/strict';
import vm from 'node:vm';

// A small DOM test double exercises generated interaction logic without adding
// a browser dependency. It does not validate visual layout or browser rendering.
class Element {
  constructor(tag) {
    this.tag = tag; this.children = []; this.attributes = {};
    this.listeners = {}; this.textContent = ''; this.value = ''; this.checked = false;
  }
  setAttribute(name, value) { this.attributes[name] = value; }
  append(...nodes) { this.children.push(...nodes); }
  replaceChildren(...nodes) { this.children = [...nodes]; }
  addEventListener(event, handler) { this.listeners[event] = handler; }
  fire(event) { assert.ok(this.listeners[event], `No listener for ${event}`); this.listeners[event](); }
}

export function verifyReportUI(html, report, name) {
  const data = html.match(/<script id="topology-data" type="application\/json">([\s\S]*?)<\/script>/);
  const source = html.match(/<\/script><script>([\s\S]*?)<\/script><\/body>/);
  assert.ok(data && source, 'Embedded data and interaction script must be present');
  assert.deepEqual(JSON.parse(data[1]), report);
  assert.ok(!/<script[^>]+src=|<link[^>]+href=/.test(html), 'Offline report must not require external assets');
  const elements = new Map([...html.matchAll(/\bid="([^"]+)"/g)].map(match => [match[1], new Element('element')]));
  elements.get('topology-data').textContent = data[1];
  elements.get('scale').value = '1000';
  elements.get('dimension').value = '1';
  elements.get('minimum').value = '0';
  const document = {
    getElementById(id) { assert.ok(elements.has(id), `Unknown element ${id}`); return elements.get(id); },
    createElement(tag) { return new Element(tag); },
    createElementNS(_ns, tag) { return new Element(tag); },
  };
  const api = vm.runInNewContext(source[1] + '\n({fmt,counts})', { document }, { timeout: 10000 });
  assert.equal(api.fmt(1000), '1000');
  assert.equal(api.fmt(0), '0');
  const alive = report.intervals.filter(i => i.dimension === 0 && i.birth <= report.cutoff && (i.death === null || i.death > report.cutoff)).length;
  assert.equal(elements.get('h0').textContent, String(alive));
  if (name === 'matrix') assert.ok(elements.get('geometry').children.some(n => n.textContent.includes('无几何坐标')));
  if (name === 'square' || name === 'ring-grid' || name === 'two-holes-grid') {
    elements.get('scale').value = name === 'square' ? '500' : '0';
    elements.get('scale').fire('input');
    assert.equal(elements.get('h1').textContent, name === 'two-holes-grid' ? '2' : '1');
    const first = elements.get('interval-table').children[0];
    assert.ok(first, 'A loop row should be available');
    first.children[0].children[0].fire('click');
    assert.ok(elements.get('geometry').children.some(n => n.attributes.stroke === '#fb923c'), 'Selecting an alive loop highlights its representative');
    elements.get('minimum').value = '999';
    elements.get('minimum').fire('input');
    assert.equal(elements.get('interval-table').children.length, 0);
  }
  function check(element) {
    for (const [key, value] of Object.entries(element.attributes)) {
      if (['points', 'x', 'y', 'x1', 'y1', 'x2', 'y2', 'cx', 'cy'].includes(key)) assert.ok(!/NaN|Infinity/.test(value));
    }
    for (const child of element.children) check(child);
  }
  check(elements.get('geometry')); check(elements.get('curve'));
}
