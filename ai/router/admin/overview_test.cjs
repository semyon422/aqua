const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const {runInNewContext} = require('node:vm');
const {setImmediate: settle} = require('node:timers/promises');

const source = readFileSync(join(__dirname, 'overview.js'), 'utf8');

function start(hidden = false) {
	let now = 0;
	let nextId = 0;
	const timers = new Map();
	const requests = [];
	const docEvents = {};
	const windowEvents = {};
	const elements = {};
	for (const id of ['overview-status', 'overview-error', 'overview-refresh', 'overview-sign-in']) {
		elements[id] = {textContent: '', hidden: true, addEventListener: (event, callback) => { elements[id][event] = callback; }};
	}
	const age = {dataset: {age: '990'}, textContent: ''};
	const reset = {dataset: {resetAt: '1005'}, textContent: ''};
	const content = {
		innerHTML: 'original snapshot',
		querySelector: () => ({dataset: {overviewNow: '1000'}}),
		querySelectorAll: selector => selector === '[data-age]' ? [age] : [reset],
	};
	elements['page-content'] = content;
	const document = {hidden, getElementById: id => elements[id], addEventListener: (name, callback) => { docEvents[name] = callback; }};
	const timer = (callback, delay, interval) => { const id = ++nextId; timers.set(id, {callback, delay, interval}); return id; };
	runInNewContext(source, {
		document, window: {addEventListener: (name, callback) => { windowEvents[name] = callback; }},
		performance: {now: () => now}, AbortController,
		setTimeout: (callback, delay) => timer(callback, delay, false), clearTimeout: id => timers.delete(id),
		setInterval: (callback, delay) => timer(callback, delay, true), clearInterval: id => timers.delete(id),
		fetch: (url, options) => new Promise((resolve, reject) => requests.push({url, options, resolve, reject})),
	});
	return {
		elements, content, age, reset, requests, timers,
		setTime: value => { now = value; },
		tick: () => { for (const timer of timers.values()) if (timer.interval) timer.callback(); },
		poll: () => {
			const entry = [...timers].find(([, timer]) => timer.delay === 30000);
			assert.ok(entry, 'next polling timer exists');
			timers.delete(entry[0]); entry[1].callback();
		},
		fireTimeout: () => {
			const entry = [...timers].find(([, timer]) => timer.delay === 10000);
			assert.ok(entry, 'request deadline exists');
			timers.delete(entry[0]); entry[1].callback();
		},
		hide: () => { document.hidden = true; docEvents.visibilitychange(); },
		show: () => { document.hidden = false; docEvents.visibilitychange(); },
		event: (name, value) => windowEvents[name](value),
	};
}

function success(request, html = '<div>fresh snapshot</div>', now = 1010) {
	request.resolve(new Response(JSON.stringify({html, now}), {headers: {'Content-Type': 'application/json'}}));
}

test('polls every 30 seconds with same-origin cookies and prevents overlapping requests', async () => {
	const view = start();
	assert.equal(view.requests.length, 0);
	view.poll();
	assert.equal(view.requests.length, 1);
	const req = view.requests[0];
	assert.equal(req.url, '/admin/overview/data');
	assert.equal(req.options.credentials, 'same-origin');
	assert.equal(req.options.cache, 'no-store');
	assert.equal(req.options.redirect, 'error');
	assert.equal(req.options.headers.Authorization, undefined);
	view.elements['overview-refresh'].click();
	assert.equal(view.requests.length, 1);
	success(req);
	await settle();
	assert.equal(view.content.innerHTML, '<div>fresh snapshot</div>');
	assert.equal(view.elements['overview-refresh'].disabled, false);
	assert.equal(view.elements['overview-error'].textContent, '');
	view.poll();
	assert.equal(view.requests.length, 2);
});

test('countdowns use server time, expire honestly and pause when hidden', () => {
	const view = start();
	assert.equal(view.age.textContent, '10s ago');
	assert.equal(view.reset.textContent, 'In 0m 5s');
	view.setTime(6000);
	view.tick();
	assert.equal(view.age.textContent, '16s ago');
	assert.equal(view.reset.textContent, 'Awaiting quota update');
	view.hide();
	assert.equal(view.timers.size, 0);
	assert.match(view.elements['overview-status'].textContent, /Paused/);
	view.setTime(60000);
	view.show();
	assert.equal(view.requests.length, 1);
	assert.equal(view.age.textContent, '70s ago');
});

test('background requests are cancelled and late responses cannot overwrite newer data', async () => {
	const view = start();
	view.poll();
	const old = view.requests[0];
	view.hide();
	assert.equal(old.options.signal.aborted, true);
	view.show();
	const latest = view.requests[1];
	success(latest, 'newer');
	await settle();
	success(old, 'obsolete');
	await settle();
	assert.equal(view.content.innerHTML, 'newer');
	assert.equal(view.elements['overview-error'].textContent, '');
});

test('network and malformed responses preserve the snapshot and recover on retry', async () => {
	const view = start();
	view.poll();
	view.requests[0].reject(new Error('PRIVATE transport details'));
	await settle();
	assert.equal(view.content.innerHTML, 'original snapshot');
	assert.match(view.elements['overview-error'].textContent, /last snapshot/);
	assert.doesNotMatch(view.elements['overview-error'].textContent, /PRIVATE/);
	view.poll();
	view.requests[1].resolve(new Response(JSON.stringify({html: 'invalid', now: 'not a timestamp'}), {headers: {'Content-Type': 'application/json'}}));
	await settle();
	assert.equal(view.content.innerHTML, 'original snapshot');
	view.poll();
	success(view.requests[2]);
	await settle();
	assert.equal(view.elements['overview-error'].textContent, '');
	assert.equal(view.content.innerHTML, '<div>fresh snapshot</div>');
});

test('HTTP failures and request deadlines retain old data and schedule another attempt', async () => {
	const view = start();
	view.poll();
	view.requests[0].resolve(new Response('PRIVATE upstream page', {status: 500}));
	await settle();
	assert.equal(view.content.innerHTML, 'original snapshot');
	assert.doesNotMatch(view.elements['overview-error'].textContent, /PRIVATE/);
	view.poll();
	const req = view.requests[1];
	req.options.signal.addEventListener('abort', () => req.reject(new Error('timeout')));
	view.fireTimeout();
	await settle();
	assert.equal(req.options.signal.aborted, true);
	assert.equal(view.content.innerHTML, 'original snapshot');
	assert.match(view.elements['overview-error'].textContent, /retrying in 30 seconds/);
	view.poll();
	assert.equal(view.requests.length, 3);
});

test('expired sessions stop polling and offer sign-in without a redirect loop', async () => {
	const view = start();
	view.poll();
	view.requests[0].resolve(new Response('{}', {status: 401}));
	await settle();
	assert.equal(view.content.innerHTML, 'original snapshot');
	assert.equal(view.elements['overview-sign-in'].hidden, false);
	assert.equal(view.elements['overview-refresh'].disabled, true);
	assert.match(view.elements['overview-status'].textContent, /Session expired/);
	assert.equal([...view.timers.values()].filter(t => !t.interval).length, 0);
	view.hide(); view.show();
	assert.equal(view.requests.length, 1);
});

test('hidden initial pages wait for visibility; leaving cancels requests and timers', async () => {
	const view = start(true);
	assert.equal(view.timers.size, 0);
	view.show();
	assert.equal(view.requests.length, 1);
	view.event('pagehide');
	assert.equal(view.requests[0].options.signal.aborted, true);
	assert.equal(view.timers.size, 1); // In-flight timeout is cleared by its finally block.
	view.requests[0].reject(new Error('aborted'));
	await settle();
	assert.equal(view.timers.size, 0);
	view.event('pageshow', {persisted: true});
	assert.equal(view.requests.length, 2);
});
