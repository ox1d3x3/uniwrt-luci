/* Run with node. Exercise LuCI menu rendering without a router or DOM dependency. */
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const title = {};
const getChildren = tree => Object.entries(tree.children || {})
 .filter(([, node]) => node.title && node.satisfied !== false)
 .map(([name, node]) => ({ ...node, name }));
const context = {
 baseclass: { extend: value => value },
 ui: { menu: { getChildren } },
 L: { env: { dispatchpath: ['admin', 'system', 'uniwrt'] } },
 _: text => text,
 document: { getElementById: () => title }
};
const source = fs.readFileSync(path.join(__dirname, '../luci-theme-uniwrt/htdocs/luci-static/resources/menu-uniwrt.js'), 'utf8');
const menu = vm.runInNewContext('(function() {' + source + '\n})()', context);
const tree = { children: {
	'uniwrt-overview': { action: { type: 'view' }, satisfied: false },
	'uniwrt-netmap': { action: { type: 'view' }, satisfied: true },
	system: { title: 'System', children: { uniwrt: { action: { type: 'template' }, satisfied: true } } }
} };
const before = JSON.stringify(tree);
const local = menu.withPageTitles(tree);
assert.equal(JSON.stringify(tree), before, 'shared menu stays unchanged for other themes');
assert.equal(getChildren(tree).some(c => c.name === 'uniwrt-netmap'), false);
assert.equal(getChildren(local).some(c => c.name === 'uniwrt-netmap'), true);
assert.equal(getChildren(local).some(c => c.name === 'uniwrt-overview'), false, 'ACL denial is retained');
assert.equal(local.children.system.children.uniwrt.title, 'UniWRT Theme');
menu.renderTitle(local, 1);
assert.equal(title.textContent, 'UniWRT Theme');
menu.renderTitle({ children: { admin: local } }, 0);
assert.equal(title.textContent, 'UniWRT Theme');

console.log('Theme menu isolation, ACL state and titles passed');
