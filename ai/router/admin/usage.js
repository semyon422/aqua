(() => {
	for (const chart of document.querySelectorAll("[data-usage-chart]")) {
		const plot = chart.querySelector("svg");
		const tooltip = chart.querySelector("[data-chart-tooltip]");
		const points = [...chart.querySelectorAll("[data-chart-point]")];
		if (!plot || !tooltip || !points.length) continue;
		let selected = -1;
		plot.setAttribute("tabindex", "0");
		plot.setAttribute("role", "group");
		const title = chart.querySelector("h2").textContent;
		plot.setAttribute("aria-label", `${title}. Use Left and Right arrows to inspect hourly values; Home and End jump to the first and last hour.`);
		plot.removeAttribute("aria-labelledby");
		tooltip.setAttribute("role", "status");
		for (const point of points) point.querySelector("title")?.remove();

		function select(index) {
			index = Math.max(0, Math.min(points.length - 1, index));
			if (selected === index) return;
			if (selected >= 0) points[selected].classList.remove("selected");
			selected = index;
			points[selected].classList.add("selected");
			tooltip.textContent = points[selected].dataset.label;
			tooltip.hidden = false;
		}

		function clear() {
			if (selected >= 0) points[selected].classList.remove("selected");
			selected = -1;
			tooltip.hidden = true;
		}

		function inspect(event) {
			const bounds = plot.getBoundingClientRect();
			if (bounds.width > 0) select(Math.floor((event.clientX - bounds.left) / bounds.width * points.length));
		}
		plot.addEventListener("pointermove", inspect);
		plot.addEventListener("pointerdown", inspect);
		plot.addEventListener("pointerleave", event => { if (event.pointerType !== "touch" && document.activeElement !== plot) clear(); });
		plot.addEventListener("pointercancel", clear);
		plot.addEventListener("focus", () => select(selected < 0 ? points.length - 1 : selected));
		plot.addEventListener("blur", clear);
		plot.addEventListener("keydown", event => {
			const current = selected < 0 ? points.length - 1 : selected;
			if (event.key === "ArrowLeft") select(current - 1);
			else if (event.key === "ArrowRight") select(current + 1);
			else if (event.key === "Home") select(0);
			else if (event.key === "End") select(points.length - 1);
			else return;
			event.preventDefault();
		});
	}
})();
