/*
 * CleanX LuCI Theme helpers
 * Defensive wrappers for wide tables/graphs so LuCI pages do not break layout.
 */
(function () {
	"use strict";

	function wrapWideTables() {
		var tables = document.querySelectorAll("table, .table");
		tables.forEach(function (table) {
			if (table.closest(".cleanx-table-scroll")) {
				return;
			}

			var parent = table.parentElement;
			if (!parent) {
				return;
			}

			var wrapper = document.createElement("div");
			wrapper.className = "cleanx-table-scroll";
			parent.insertBefore(wrapper, table);
			wrapper.appendChild(table);
		});
	}

	function markCurrentPage() {
		var path = window.location.pathname.replace(/^\/cgi-bin\/luci\/?/, "").replace(/\//g, "-");
		if (path) {
			document.documentElement.setAttribute("data-cleanx-page", path);
			document.body.setAttribute("data-page", path);
		}
	}

	function fixGraphSizing() {
		var graphs = document.querySelectorAll("svg, canvas");
		graphs.forEach(function (graph) {
			graph.style.maxWidth = "100%";
			if (graph.tagName.toLowerCase() === "canvas") {
				graph.style.width = "100%";
			}
		});
	}

	function run() {
		markCurrentPage();
		wrapWideTables();
		fixGraphSizing();
	}

	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", run);
	} else {
		run();
	}

	window.addEventListener("resize", fixGraphSizing);
})();
