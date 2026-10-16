const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const {runInNewContext} = require('node:vm');
const source = readFileSync(join(__dirname, 'usage.js'), 'utf8');

function start() {
	const events = {};
	const attributes = {};
	const points = ['first hour · Input: 0', 'middle hour · Input: 20', '<script>literal label</script>'].map(label => {
		const classes = new Set();
		return {dataset: {label}, classList: {add: c => classes.add(c), remove: c => classes.delete(c)}, classes,
			querySelector: () => ({remove() {}})};
	});
	const plot = {setAttribute: (key, value) => { attributes[key] = value; }, removeAttribute: key => delete attributes[key],
		addEventListener: (key, callback) => { events[key] = callback; }, getBoundingClientRect: () => ({left: 100, width: 300})};
	const tooltip = {hidden: true, textContent: '', setAttribute() {}};
	const chart = {querySelector: selector => selector === 'svg' ? plot : selector === 'h2' ? {textContent: 'Tokens'} : tooltip,
		querySelectorAll: () => points};
	const document = {querySelectorAll: () => [chart], activeElement: null};
	runInNewContext(source, {document});
	return {document, plot, tooltip, points, events, attributes};
}

test('keyboard navigation is bounded, announces exact values and cleans selection on blur', () => {
	const view = start();
	assert.equal(view.attributes.tabindex, '0');
	assert.match(view.attributes['aria-label'], /Left and Right/);
	view.events.focus();
	assert.equal(view.tooltip.textContent, '<script>literal label</script>');
	assert.equal(view.tooltip.hidden, false);
	let prevented = 0;
	const key = name => view.events.keydown({key: name, preventDefault: () => prevented++});
	key('ArrowLeft');
	assert.equal(view.tooltip.textContent, 'middle hour · Input: 20');
	key('Home'); key('ArrowLeft');
	assert.equal(view.tooltip.textContent, 'first hour · Input: 0');
	key('End'); key('ArrowRight');
	assert.equal(view.tooltip.textContent, '<script>literal label</script>');
	key('Tab');
	assert.equal(prevented, 5);
	assert.equal(view.points.filter(p => p.classes.has('selected')).length, 1);
	view.events.blur();
	assert.equal(view.tooltip.hidden, true);
	assert.equal(view.points.filter(p => p.classes.has('selected')).length, 0);
});

test('pointer position maps to an hourly bucket and keyboard focus preserves the tooltip', () => {
	const view = start();
	view.events.pointermove({clientX: 250});
	assert.equal(view.tooltip.textContent, 'middle hour · Input: 20');
	view.events.pointermove({clientX: 99});
	assert.equal(view.tooltip.textContent, 'first hour · Input: 0');
	view.events.pointermove({clientX: 401});
	assert.equal(view.tooltip.textContent, '<script>literal label</script>');
	view.document.activeElement = view.plot;
	view.events.pointerleave({pointerType: 'mouse'});
	assert.equal(view.tooltip.hidden, false);
	view.document.activeElement = null;
	view.events.pointerleave({pointerType: 'mouse'});
	assert.equal(view.tooltip.hidden, true);
	view.events.pointerdown({clientX: 250, pointerType: 'touch'});
	assert.equal(view.tooltip.textContent, 'middle hour · Input: 20');
	view.events.pointerleave({pointerType: 'touch'});
	assert.equal(view.tooltip.hidden, false);
	view.events.pointercancel();
	assert.equal(view.tooltip.hidden, true);
});

test('other pages with no charts need no dependencies or requests', () => {
	assert.doesNotThrow(() => runInNewContext(source, {document: {querySelectorAll: () => []}}));
});
