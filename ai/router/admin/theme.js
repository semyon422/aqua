(() => {
	const key = "ai-router-theme";
	const valid = value => ["system", "dark", "light"].includes(value);
	let theme = "system";
	try {
		const stored = localStorage.getItem(key);
		if (valid(stored)) theme = stored;
	} catch (_) { /* Storage can be disabled; system theme still works. */ }
	const apply = value => {
		if (value === "system") delete document.documentElement.dataset.theme;
		else document.documentElement.dataset.theme = value;
	};
	apply(theme);
	document.addEventListener("DOMContentLoaded", () => {
		const control = document.getElementById("theme");
		if (!control) return;
		control.value = theme;
		control.addEventListener("change", () => {
			if (!valid(control.value)) return;
			theme = control.value;
			apply(theme);
			try { localStorage.setItem(key, theme); } catch (_) { /* Optional preference only. */ }
		});
	});
})();
