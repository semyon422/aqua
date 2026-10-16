const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const {runInNewContext} = require('node:vm');

const source = readFileSync(join(__dirname, 'theme.js'), 'utf8');

function start(stored, blocked = false) {
	const dataset = {};
	const saved = [];
	let ready;
	let change;
	const control = {value: '', addEventListener: (_, callback) => { change = callback; }};
	runInNewContext(source, {
		document: {
			documentElement: {dataset},
			addEventListener: (_, callback) => { ready = callback; },
			getElementById: () => control,
		},
		localStorage: {
			getItem: () => { if (blocked) throw new Error('Storage disabled'); return stored; },
			setItem: (key, value) => { if (blocked) throw new Error('Storage disabled'); saved.push([key, value]); },
		},
	});
	ready();
	return {dataset, control, saved, select: value => { control.value = value; change(); }};
}

test('restore a theme and return to the system preference', () => {
	const view = start('dark');
	assert.equal(view.dataset.theme, 'dark');
	assert.equal(view.control.value, 'dark');
	view.select('light');
	assert.equal(view.dataset.theme, 'light');
	view.select('system');
	assert.equal(view.dataset.theme, undefined);
	assert.deepEqual(view.saved, [['ai-router-theme', 'light'], ['ai-router-theme', 'system']]);
});

test('untrusted stored themes and select values are ignored', () => {
	const view = start('<script>');
	assert.equal(view.control.value, 'system');
	assert.equal(view.dataset.theme, undefined);
	view.select('invalid');
	assert.deepEqual(view.saved, []);
	assert.equal(view.dataset.theme, undefined);
});

test('unavailable storage does not break theme switching', () => {
	const view = start(null, true);
	assert.equal(view.control.value, 'system');
	assert.doesNotThrow(() => view.select('dark'));
	assert.equal(view.dataset.theme, 'dark');
});
