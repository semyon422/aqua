(() => {
	const content = document.getElementById("page-content");
	const status = document.getElementById("overview-status");
	const error = document.getElementById("overview-error");
	const button = document.getElementById("overview-refresh");
	const signIn = document.getElementById("overview-sign-in");
	const initial = content?.querySelector("[data-overview-now]");
	if (!initial || !status || !error || !button || !signIn) return;

	const period = 30000;
	let serverTime = Number(initial.dataset.overviewNow);
	if (!Number.isFinite(serverTime)) return;
	let receivedAt = performance.now();
	let pollTimer;
	let clockTimer;
	let active;
	let expired = false;
	let stopped = false;
	button.hidden = false;

	function duration(seconds) {
		seconds = Math.max(0, Math.ceil(seconds));
		const days = Math.floor(seconds / 86400);
		const hours = Math.floor(seconds % 86400 / 3600);
		const minutes = Math.floor(seconds % 3600 / 60);
		if (days) return `${days}d ${hours}h`;
		if (hours) return `${hours}h ${minutes}m`;
		return `${minutes}m ${seconds % 60}s`;
	}

	function tick() {
		const elapsed = Math.max(0, (performance.now() - receivedAt) / 1000);
		const now = serverTime + elapsed;
		for (const node of content.querySelectorAll("[data-age]")) {
			node.textContent = `${Math.max(0, Math.floor(now - Number(node.dataset.age)))}s ago`;
		}
		for (const node of content.querySelectorAll("[data-reset-at]")) {
			const left = Number(node.dataset.resetAt) - now;
			node.textContent = left > 0 ? `In ${duration(left)}` : "Awaiting quota update";
		}
		const prefix = expired ? "Session expired" : document.hidden ? "Paused while tab is hidden" : active ? "Updating" : "Auto-refresh every 30s";
		status.textContent = `${prefix} · last page update ${duration(elapsed)} ago`;
	}

	function schedule() {
		clearTimeout(pollTimer);
		if (!stopped && !expired && !document.hidden) pollTimer = setTimeout(refresh, period);
	}

	async function refresh() {
		if (stopped || expired || document.hidden || active) return;
		clearTimeout(pollTimer);
		const controller = new AbortController();
		active = controller;
		button.disabled = true;
		tick();
		const timeout = setTimeout(() => controller.abort(), 10000);
		try {
			const response = await fetch("/admin/overview/data", {
				credentials: "same-origin", cache: "no-store", redirect: "error",
				headers: {Accept: "application/json"}, signal: controller.signal,
			});
			if (active !== controller || controller.signal.aborted) return;
			if (response.status === 401 || response.status === 403) {
				expired = true;
				error.textContent = "Your session expired. Sign in again to resume updates.";
				signIn.hidden = false;
				return;
			}
			if (!response.ok || !response.headers.get("Content-Type")?.includes("application/json")) throw new Error("Update failed");
			const data = await response.json();
			if (active !== controller || controller.signal.aborted) return;
			if (typeof data.html !== "string" || !Number.isInteger(data.now)) throw new Error("Invalid update");
			// Same-origin, cookie-authenticated etlua fragment; dynamic values are escaped on the server.
			content.innerHTML = data.html;
			serverTime = data.now;
			receivedAt = performance.now();
			error.textContent = "";
		} catch (_) {
			if (active === controller && !stopped && !document.hidden) {
				error.textContent = "Could not update Overview. Showing the last snapshot; retrying in 30 seconds.";
			}
		} finally {
			clearTimeout(timeout);
			if (active === controller) {
				active = undefined;
				button.disabled = expired;
				tick();
				schedule();
			}
		}
	}

	function pause() {
		clearTimeout(pollTimer);
		clearInterval(clockTimer);
		active?.abort();
		active = undefined;
		button.disabled = expired;
	}

	function startClock() {
		clearInterval(clockTimer);
		if (!stopped && !document.hidden) clockTimer = setInterval(tick, 1000);
		tick();
	}

	button.addEventListener("click", refresh);
	document.addEventListener("visibilitychange", () => {
		if (document.hidden) { pause(); tick(); }
		else { startClock(); refresh(); }
	});
	window.addEventListener("pagehide", () => { stopped = true; pause(); });
	window.addEventListener("pageshow", event => {
		if (event.persisted) { stopped = false; startClock(); refresh(); }
	});
	startClock();
	schedule();
})();
