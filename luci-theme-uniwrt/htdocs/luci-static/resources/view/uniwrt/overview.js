'use strict';
'require view';
'require rpc';
'require poll';
'require network';

var callBoard = rpc.declare({ object: 'system', method: 'board' });
var callInfo  = rpc.declare({ object: 'system', method: 'info' });
var callIfDump = rpc.declare({ object: 'network.interface', method: 'dump', expect: { 'interface': [] } });
var callWifi  = rpc.declare({ object: 'luci-rpc', method: 'getWirelessDevices', expect: { '': {} } });

function fmtBytes(b) {
	if (!b && b !== 0) return '–';
	if (b >= 1073741824) return (b / 1073741824).toFixed(2) + ' GB';
	if (b >= 1048576) return (b / 1048576).toFixed(1) + ' MB';
	if (b >= 1024) return (b / 1024).toFixed(0) + ' KB';
	return b + ' B';
}
function fmtUptime(s) {
	if (!s) return '–';
	var d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
	var p = [];
	if (d) p.push(d + 'd');
	if (h) p.push(h + 'h');
	p.push(m + 'm');
	return p.join(' ');
}
function level(pct) { return pct < 60 ? 'ok' : pct < 85 ? 'warn' : 'crit'; }

function metricCard(icon, title, valueId, subId, withMeter) {
	var body = [
		E('div', { 'class': 'u-card-head' }, [
			E('div', { 'class': 'u-card-ico' }, [ E('span', { 'innerHTML': icon }) ]),
			E('div', { 'class': 'u-card-title' }, [ title ])
		]),
		E('div', { 'class': 'u-card-metric', 'id': valueId }, [ '–' ])
	];
	if (withMeter)
		body.push(E('div', { 'class': 'u-meter', 'id': valueId + '-meter' }, [ E('i', { 'style': 'width:0%' }) ]));
	body.push(E('div', { 'class': 'u-card-sub', 'id': subId }, [ '' ]));
	return E('div', { 'class': 'u-card' }, body);
}

var ICO = {
	chip:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/><line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/><line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="14" x2="23" y2="14"/><line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="14" x2="4" y2="14"/></svg>',
	ram:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="20" height="10" rx="1"/><line x1="6" y1="7" x2="6" y2="17"/><line x1="12" y1="7" x2="12" y2="17"/><line x1="18" y1="7" x2="18" y2="17"/></svg>',
	clock:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><polyline points="12 7 12 12 16 14"/></svg>',
	box:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>',
	globe:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><line x1="3" y1="12" x2="21" y2="12"/><path d="M12 3a15 15 0 014 9 15 15 0 01-4 9 15 15 0 01-4-9 15 15 0 014-9z"/></svg>',
	wifi:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.55a11 11 0 0114 0"/><path d="M1.42 9a16 16 0 0121.16 0"/><path d="M8.53 16.11a6 6 0 016.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></svg>'
};

return view.extend({
	prevTotal: 0, prevIdle: 0,

	load: function() {
		return Promise.all([
			L.resolveDefault(callBoard(), {}),
			L.resolveDefault(callInfo(), {})
		]);
	},

	render: function(data) {
		var board = data[0] || {}, info = data[1] || {};
		var self = this;

		var grid = E('div', { 'class': 'u-grid' }, [
			metricCard(ICO.box,   _('System'),  'u-ov-sys',  'u-ov-sys-sub',  false),
			metricCard(ICO.chip,  _('CPU Load'),'u-ov-cpu',  'u-ov-cpu-sub',  true),
			metricCard(ICO.ram,   _('Memory'),  'u-ov-ram',  'u-ov-ram-sub',  true),
			metricCard(ICO.clock, _('Uptime'),  'u-ov-up',   'u-ov-up-sub',   false)
		]);

		var ifaceCard = E('div', { 'class': 'u-card' }, [
			E('div', { 'class': 'u-card-head' }, [
				E('div', { 'class': 'u-card-ico' }, [ E('span', { 'innerHTML': ICO.globe }) ]),
				E('div', { 'class': 'u-card-title' }, [ _('Network Interfaces') ])
			]),
			E('div', { 'id': 'u-ov-ifaces' }, [ E('div', { 'class': 'u-card-sub' }, [ _('Loading…') ]) ])
		]);

		var wifiCard = E('div', { 'class': 'u-card' }, [
			E('div', { 'class': 'u-card-head' }, [
				E('div', { 'class': 'u-card-ico' }, [ E('span', { 'innerHTML': ICO.wifi }) ]),
				E('div', { 'class': 'u-card-title' }, [ _('Wireless') ])
			]),
			E('div', { 'id': 'u-ov-wifi' }, [ E('div', { 'class': 'u-card-sub' }, [ _('Loading…') ]) ])
		]);

		var root = E('div', {}, [
			E('p', { 'class': 'cbi-map-descr' }, [ _('Live overview of this device. Figures refresh automatically.') ]),
			grid,
			E('div', { 'class': 'u-grid', 'style': 'grid-template-columns:repeat(auto-fill,minmax(320px,1fr))' }, [ ifaceCard, wifiCard ])
		]);

		/* static system card */
		var sysVal = board.model || board.board_name || '–';
		var sysSub = [ board.release ? (board.release.distribution + ' ' + board.release.version) : '', board.kernel ? ('Kernel ' + board.kernel) : '' ].filter(Boolean).join(' · ');
		root.querySelector('#u-ov-sys').textContent = sysVal;
		root.querySelector('#u-ov-sys').style.fontSize = '1.05rem';
		root.querySelector('#u-ov-sys-sub').textContent = sysSub;

		this.update(info);

		poll.add(function() {
			return Promise.all([
				L.resolveDefault(callInfo(), {}),
				L.resolveDefault(callIfDump(), []),
				L.resolveDefault(callWifi(), {})
			]).then(function(d) {
				self.update(d[0]);
				self.updateIfaces(d[1]);
				self.updateWifi(d[2]);
			});
		}, 5);

		/* first interface/wifi paint */
		Promise.all([ L.resolveDefault(callIfDump(), []), L.resolveDefault(callWifi(), {}) ])
			.then(function(d) { self.updateIfaces(d[0]); self.updateWifi(d[1]); });

		return root;
	},

	update: function(info) {
		if (!info) return;
		var $ = function(id) { return document.getElementById(id); };

		if (info.load && $('u-ov-cpu')) {
			var load1 = info.load[0] / 65536;
			var cores = (navigator.hardwareConcurrency || 1);
			var pct = Math.min(load1 / cores, 1) * 100;
			$('u-ov-cpu').textContent = pct.toFixed(0) + '%';
			var meter = $('u-ov-cpu-meter');
			if (meter) { meter.className = 'u-meter ' + level(pct); meter.firstElementChild.style.width = pct.toFixed(0) + '%'; }
			$('u-ov-cpu-sub').textContent = _('Load average') + ': ' + load1.toFixed(2);
		}
		if (info.memory && $('u-ov-ram')) {
			var total = info.memory.total, avail = info.memory.available || info.memory.free, used = total - avail;
			var pct = used / total * 100;
			$('u-ov-ram').textContent = pct.toFixed(0) + '%';
			var meter = $('u-ov-ram-meter');
			if (meter) { meter.className = 'u-meter ' + level(pct); meter.firstElementChild.style.width = pct.toFixed(0) + '%'; }
			$('u-ov-ram-sub').textContent = fmtBytes(used) + ' / ' + fmtBytes(total);
		}
		if (info.uptime && $('u-ov-up')) {
			$('u-ov-up').textContent = fmtUptime(info.uptime);
			$('u-ov-up').style.fontSize = '1.4rem';
			if (info.localtime) $('u-ov-up-sub').textContent = new Date(info.localtime * 1000).toLocaleString();
		}
	},

	updateIfaces: function(ifaces) {
		var box = document.getElementById('u-ov-ifaces');
		if (!box || !Array.isArray(ifaces)) return;
		var rows = [];
		ifaces.forEach(function(iface) {
			if (iface.interface === 'loopback') return;
			var up = !!iface.up;
			var addr = (iface['ipv4-address'] && iface['ipv4-address'][0]) ? iface['ipv4-address'][0].address : null;
			if (!addr && iface['ipv6-address'] && iface['ipv6-address'][0]) addr = iface['ipv6-address'][0].address;
			rows.push(E('div', { 'class': 'u-kv' }, [
				E('span', { 'class': 'k' }, [ E('span', { 'class': 'u-dot ' + (up ? 'up' : 'down') }), iface.interface ]),
				E('span', { 'class': 'v' }, [ addr || (up ? _('up') : _('down')) ])
			]));
		});
		box.innerHTML = '';
		rows.length ? rows.forEach(function(r) { box.appendChild(r); }) : box.appendChild(E('div', { 'class': 'u-card-sub' }, [ _('No interfaces') ]));
	},

	updateWifi: function(wifi) {
		var box = document.getElementById('u-ov-wifi');
		if (!box || !wifi) return;
		var rows = [];
		Object.keys(wifi).forEach(function(dev) {
			var ifaces = (wifi[dev] && wifi[dev].interfaces) || [];
			ifaces.forEach(function(i) {
				var cfg = i.config || {}, iw = i.iwinfo || {};
				var ssid = cfg.ssid || iw.ssid || '–';
				var up = !!i.up;
				rows.push(E('div', { 'class': 'u-kv' }, [
					E('span', { 'class': 'k' }, [ E('span', { 'class': 'u-dot ' + (up ? 'up' : 'down') }), ssid ]),
					E('span', { 'class': 'v' }, [ (iw.channel ? ('ch ' + iw.channel) : '') + (iw.signal ? ('  ' + iw.signal + ' dBm') : '') || dev ])
				]));
			});
		});
		box.innerHTML = '';
		rows.length ? rows.forEach(function(r) { box.appendChild(r); }) : box.appendChild(E('div', { 'class': 'u-card-sub' }, [ _('No wireless radios') ]));
	},

	handleSaveApply: null, handleSave: null, handleReset: null
});
