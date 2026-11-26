/* Run with node. Exercise LuCI menu rendering without a router or DOM dependency. */
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

class Element {
	constructor(tag, attrs = {}, children = []) {
		this.tag = tag;
		this.attrs = attrs;
		this.children = [];
		this.listeners = {};
		const classes = new Set((attrs.class || '').split(/\s+/).filter(Boolean));
		this.classList = {
			add: c => classes.add(c),
			remove: c => classes.delete(c),
			contains: c => classes.has(c),
			toggle: (c, force) => {
				const on = force === undefined ? !classes.has(c) : force;
				on ? classes.add(c) : classes.delete(c);
				return on;
			}
		};
		children.forEach(c => this.appendChild(c));
	}
	appendChild(child) {
		this.children.push(child);
		if (child instanceof Element) child.parentNode = this;
	}
	insertBefore(child, ref) {
		this.children.splice(Math.max(0, this.children.indexOf(ref)), 0, child);
		child.parentNode = this;
	}
	get firstChild() { return this.children[0]; }
	get previousElementSibling() {
		return this.parentNode.children[this.parentNode.children.indexOf(this) - 1];
	}
	querySelectorAll(selector) {
		const classes = selector.split('.').filter(Boolean);
		return this.children.filter(c => c instanceof Element).flatMap(c => [
			...(classes.every(k => c.classList.contains(k)) ? [c] : []),
			...c.querySelectorAll(selector)
		]);
	}
	addEventListener(type, fn) { this.listeners[type] = fn; }
	click(overrides = {}) {
		const event = { button: 0, preventDefault() { this.defaultPrevented = true; }, ...overrides };
		this.listeners.click(event);
		return event;
	}
}

let mode = 'current';
const title = {};
const getChildren = tree => Object.entries(tree.children || {})
	.filter(([, node]) => node.title && node.satisfied !== false)
	.map(([name, node]) => ({ ...node, name }));
const context = {
	baseclass: { extend: value => value },
	ui: { menu: { getChildren } },
	L: { env: { dispatchpath: ['admin', 'system', 'uniwrt'] }, url: (...parts) => '/' + parts.join('/') },
	_: text => text,
	E: (tag, attrs, children) => new Element(tag, attrs, children),
	document: {
		documentElement: { getAttribute: name => name === 'data-uniwrt-menu' ? mode : '1' },
		getElementById: () => title
	},
	requestAnimationFrame: () => {}
};
const source = fs.readFileSync(path.join(__dirname, '../luci-theme-uniwrt/htdocs/luci-static/resources/menu-uniwrt.js'), 'utf8');
const menu = vm.runInNewContext('(function() {' + source + '\n})()', context);
menu.getIcon = () => new Element('svg');

const sections = { children: Object.fromEntries(['system', 'network', 'services'].map(name => [name, {
	title: name, children: { settings: { title: 'Settings' } }
}])) };
for (const expanded of [false, true]) {
	mode = expanded ? 'expanded' : 'current';
	const container = new Element('nav');
	menu.renderSidebar(container, sections, 'admin');
	const group = container.children[0];
	const links = group.children.filter(c => c.tag === 'a');
	const panels = group.querySelectorAll('.u-nav-sub');
	assert.equal(panels.filter(p => p.classList.contains('open')).length, expanded ? 3 : 1);
	links[1].click(); // opens Network in single-section mode, closes it in expanded mode
	assert.equal(panels[0].classList.contains('open'), expanded);
	assert.equal(panels[1].classList.contains('open'), !expanded);
	assert.equal(links[0].classList.contains('open'), panels[0].classList.contains('open'));
	const state = panels.map(p => p.classList.contains('open'));
	for (const modifiers of [{ ctrlKey: true }, { metaKey: true }, { shiftKey: true }, { altKey: true }, { button: 1 }]) {
		assert.equal(links[2].click(modifiers).defaultPrevented, undefined);
		assert.deepEqual(panels.map(p => p.classList.contains('open')), state);
	}
	links[1].click();
	assert.equal(panels[1].classList.contains('open'), expanded);
}
console.log('Accordion modes and modifier clicks passed');
