'use strict';
'require view';
'require rpc';
'require poll';
'require ui';
'require uci';

/*
 * UniWRT Network Map
 *
 * Internet -> router -> Wi-Fi networks / wired networks -> client devices,
 * with live traffic and device-type icons the user can override.
 *
 * Router cost is kept at the level of LuCI's own Status -> Overview page:
 * one batched ubus request per refresh, only while this page is open and
 * visible, using data the router already keeps (DHCP leases, neighbour
 * table, Wi-Fi station list, interface counters). Layout, device
 * detection, rate maths and animation all run in the browser.
 */

var callHints   = rpc.declare({ object: 'luci-rpc', method: 'getHostHints', expect: { '': {} } });
var callWifi    = rpc.declare({ object: 'luci-rpc', method: 'getWirelessDevices', expect: { '': {} } });
var callNetDevs = rpc.declare({ object: 'luci-rpc', method: 'getNetworkDevices', expect: { '': {} } });
var callBoard   = rpc.declare({ object: 'luci-rpc', method: 'getBoardJSON', expect: { '': {} } });
var callIfDump  = rpc.declare({ object: 'network.interface', method: 'dump', expect: { 'interface': [] } });
var callAssoc   = rpc.declare({ object: 'iwinfo', method: 'assoclist', params: [ 'device' ], expect: { results: [] } });
var callUfp     = rpc.declare({ object: 'fingerprint', method: 'fingerprint', expect: { '': {} } });
var callCommit  = rpc.declare({ object: 'uci', method: 'commit', params: [ 'config' ] });

/* ------------------------------------------------------------------ icons */
var S = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">';
var ICONS = {
	phone:     S + '<rect x="7" y="2" width="10" height="20" rx="2.2"/><line x1="11" y1="18.5" x2="13" y2="18.5"/></svg>',
	tablet:    S + '<rect x="4" y="2.5" width="16" height="19" rx="2.2"/><line x1="11" y1="18.5" x2="13" y2="18.5"/></svg>',
	laptop:    S + '<rect x="4.5" y="5" width="15" height="10.5" rx="1.5"/><path d="M2.5 19h19l-1.6-3.5H4.1z"/></svg>',
	desktop:   S + '<rect x="3" y="3.5" width="18" height="12.5" rx="1.6"/><line x1="12" y1="16" x2="12" y2="20"/><line x1="8" y1="20.5" x2="16" y2="20.5"/></svg>',
	tv:        S + '<rect x="2.5" y="6" width="19" height="12.5" rx="2"/><polyline points="8.5 2.5 12 6 15.5 2.5"/><line x1="8" y1="21.5" x2="16" y2="21.5"/></svg>',
	camera:    S + '<path d="M3 6.5h12.5l3.5 2.5v3l-3.5 2.5H3z"/><circle cx="7" cy="10.5" r="1.2"/><path d="M9 14.5v3.5H5.5"/><line x1="4" y1="16" x2="4" y2="20"/></svg>',
	iot:       S + '<rect x="5" y="3" width="14" height="18" rx="4"/><line x1="10" y1="9" x2="10" y2="12"/><line x1="14" y1="9" x2="14" y2="12"/><path d="M10 16a2 2 0 004 0"/></svg>',
	speaker:   S + '<rect x="6" y="2.5" width="12" height="19" rx="2.5"/><circle cx="12" cy="14.5" r="3.2"/><circle cx="12" cy="7" r=".9"/></svg>',
	printer:   S + '<path d="M6.5 9V3h11v6"/><rect x="3" y="9" width="18" height="8" rx="2"/><rect x="6.5" y="14" width="11" height="7"/><line x1="17" y1="12" x2="17.01" y2="12"/></svg>',
	console:   S + '<path d="M7 8h10a5 5 0 015 5v.5a3.5 3.5 0 01-6.2 2.2L14.5 14h-5l-1.3 1.7A3.5 3.5 0 012 13.5V13a5 5 0 015-5z"/><line x1="7.5" y1="10.5" x2="7.5" y2="13.5"/><line x1="6" y1="12" x2="9" y2="12"/><line x1="16" y1="11" x2="16.01" y2="11"/><line x1="18" y1="13" x2="18.01" y2="13"/></svg>',
	server:    S + '<rect x="4" y="3" width="16" height="7.5" rx="1.6"/><rect x="4" y="13.5" width="16" height="7.5" rx="1.6"/><line x1="8" y1="6.75" x2="8.01" y2="6.75"/><line x1="8" y1="17.25" x2="8.01" y2="17.25"/><line x1="12" y1="6.75" x2="16" y2="6.75"/><line x1="12" y1="17.25" x2="16" y2="17.25"/></svg>',
	network:   S + '<rect x="3" y="14" width="18" height="6.5" rx="2"/><line x1="7" y1="17.25" x2="7.01" y2="17.25"/><path d="M8.5 10.5a5 5 0 017 0"/><path d="M5.5 7.5a9.2 9.2 0 0113 0"/></svg>',
	watch:     S + '<rect x="6.5" y="6" width="11" height="12" rx="3"/><path d="M9 6l.8-3.5h4.4L15 6"/><path d="M9 18l.8 3.5h4.4L15 18"/></svg>',
	appliance: S + '<rect x="6" y="2" width="12" height="20" rx="2"/><line x1="6" y1="9" x2="18" y2="9"/><line x1="9" y1="5" x2="9" y2="6.5"/><line x1="9" y1="12" x2="9" y2="15"/></svg>',
	car:       S + '<path d="M4.5 16.5v-3.2L6.7 8h10.6l2.2 5.3v3.2z"/><line x1="4.5" y1="13.3" x2="19.5" y2="13.3"/><circle cx="8" cy="16.8" r="1.6"/><circle cx="16" cy="16.8" r="1.6"/></svg>',
	generic:   S + '<rect x="5" y="4" width="14" height="16" rx="2.5"/><circle cx="12" cy="12" r="2.5"/></svg>',
	/* map nodes */
	internet:  S + '<circle cx="12" cy="12" r="9"/><line x1="3" y1="12" x2="21" y2="12"/><path d="M12 3a14 14 0 014 9 14 14 0 01-4 9 14 14 0 01-4-9 14 14 0 014-9z"/></svg>',
	router:    S + '<rect x="2.5" y="12.5" width="19" height="7" rx="2"/><line x1="6.5" y1="16" x2="6.51" y2="16"/><line x1="10" y1="16" x2="10.01" y2="16"/><line x1="7" y1="12.5" x2="5" y2="5"/><line x1="17" y1="12.5" x2="19" y2="5"/></svg>',
	wifi:      S + '<path d="M5 12.5a10 10 0 0114 0"/><path d="M1.8 9.2a14.5 14.5 0 0120.4 0"/><path d="M8.5 15.8a5 5 0 017 0"/><line x1="12" y1="19.5" x2="12.01" y2="19.5"/></svg>',
	wired:     S + '<rect x="5" y="9" width="14" height="10" rx="1.5"/><path d="M9 9V5h6v4"/><line x1="9" y1="13" x2="9" y2="15"/><line x1="12" y1="13" x2="12" y2="15"/><line x1="15" y1="13" x2="15" y2="15"/></svg>'
};

var TYPES = [
	[ 'phone',     _('Phone') ],     [ 'tablet',  _('Tablet') ],   [ 'laptop',  _('Laptop') ],
	[ 'desktop',   _('Computer') ],  [ 'tv',      _('TV / Streamer') ], [ 'camera', _('Camera / CCTV') ],
	[ 'iot',       _('Smart device') ], [ 'speaker', _('Speaker') ], [ 'printer', _('Printer') ],
	[ 'console',   _('Game console') ], [ 'server', _('Server / NAS') ], [ 'network', _('Access point / Switch') ],
	[ 'watch',     _('Watch') ],     [ 'appliance', _('Appliance') ], [ 'car', _('Car') ],
	[ 'generic',   _('Other') ]
];
var TYPE_NAME = {};
TYPES.forEach(function(t) { TYPE_NAME[t[0]] = t[1]; });

function icon(name, cls) {
	var markup = ICONS[name] || ICONS.generic;
	var span = E('span', { 'class': 'u-nm-ico' + (cls ? ' ' + cls : ''), 'aria-hidden': 'true' });
	span.innerHTML = markup;   /* static markup from this file only */
	return span;
}

/* ------------------------------------------------------ device detection
 * Best guess, cheapest signal first, always explainable and overridable.
 * Order: user choice > ufp (if installed) > hostname > maker prefix >
 * private (randomised) Wi-Fi MAC > connection type. */
var NAME_RULES = [
	[ 'console',   /playstation|\bps[345]\b|ps[345][-_ ]|xbox|nintendo|\bswitch[-_ ]?(oled|lite)?$|steam[-_ ]?deck/i ],
	[ 'tablet',    /ipad|galaxy[-_ ]?tab|[-_ ]tab[-_ ]|[-_]tab$|kindle|fire[-_ ]?hd|lenovo[-_ ]?tab|mipad|matepad/i ],
	[ 'watch',     /watch/i ],
	[ 'phone',     /iphone|android|galaxy|pixel|oneplus|redmi|xiaomi|poco|huawei|honor|oppo|vivo|realme|nokia|motorola|moto[-_ ]?g|nothing[-_ ]?phone|\bsm-[a-z]\d/i ],
	[ 'laptop',    /macbook|laptop|notebook|thinkpad|xps|zenbook|vivobook|ideapad|yoga|elitebook|probook|latitude|surface|chromebook/i ],
	[ 'tv',        /\btv\b|[-_]tv|tv[-_]|bravia|webos|tizen|roku|chromecast|fire[-_ ]?tv|firestick|shield|apple[-_ ]?tv|mibox|google[-_ ]?tv/i ],
	[ 'camera',    /\bcam|cam\b|camera|\bipc|nvr|dvr|hikvision|dahua|reolink|ezviz|wyze|blink|arlo|imou|annke|amcrest|tapo[-_ ]?c\d|\bds-\d/i ],
	[ 'speaker',   /echo|alexa|google[-_ ]?home|nest[-_ ]?(mini|audio|hub)|homepod|sonos|speaker/i ],
	[ 'printer',   /printer|epson|brother|canon|laserjet|deskjet|officejet|envy|^hp[0-9a-f]{6}|^npi[0-9a-f]/i ],
	[ 'server',    /\bnas\b|synology|diskstation|qnap|truenas|unraid|server|proxmox|\bpve\b|zima|casaos|raspberrypi|pi[-_ ]?hole|homeassistant|home[-_ ]?assistant|ubuntu|debian/i ],
	[ 'iot',       /^esp[-_]|espressif|tasmota|shelly|tuya|sonoff|smart[-_ ]?plug|[-_]plug|bulb|lamp|light|hue|yeelight|kasa|meross|wled|zigbee|thermostat|doorbell|sensor/i ],
	[ 'appliance', /fridge|refrigerator|washer|washing|dryer|dishwasher|oven|aircon|air[-_ ]?con|vacuum|roborock|roomba|dreame|ecovacs|purifier/i ],
	[ 'car',       /tesla|\bcar\b|vehicle/i ],
	[ 'network',   /access[-_ ]?point|\bap\b|router|\buap\b|openwrt|mesh|deco|eero|repeater|extender/i ],
	[ 'desktop',   /^desktop-|^pc-|-pc$|imac|mac[-_ ]?mini|mac[-_ ]?studio|workstation|^win-/i ]
];
/* A few high-confidence maker prefixes; a full OUI database would not fit. */
var OUI = {
	iot:     [ '240AC4','246F28','30AEA4','3C71BF','7C9EBD','84F3EB','8CAAB5','A4CF12','BCDDC2','C82B96','CC50E3','DC4F22','ECFABC','483FDA','E8DB84','349454','441793','58BF25','083AF2','10521C','40225D','94B97E','A842E3','C44F33','E05A1B','001788','ECB5FA' ],
	server:  [ 'B827EB','DCA632','E45F01','D83ADD','2CCF67','001132' ],
	camera:  [ '2857BE','4419B6','4CBD8F','BCAD28','C056E3','E0CA3C','54C415','3CEF8C','4C11BF','9002A9','A0BD1D','E0508B' ],
	speaker: [ '000E58','5CAAFD','7828CA','949F3E','B8E937','48A6B8','347E5C' ],
	tv:      [ 'B0A737','D83134','CC6DA0','080581','AC3A7A','DC3A5E' ],
	console: [ '98B6E9','7CBB8A','0403D6','582F40','E84ECE','34AF2C' ],
	network: [ '24A43C','44D9E7','687251','7483C2','788A20','802AA8','B4FBE4','DC9FDB','F09FC2','FCECDA','E063DA','18E829' ]
};
var OUI_MAP = {};
Object.keys(OUI).forEach(function(t) { OUI[t].forEach(function(p) { OUI_MAP[p] = t; }); });

function isPrivateMac(mac) { return (parseInt(mac.substr(0, 2), 16) & 2) === 2; }

function classify(c, ufp) {
	var n = c.name || '';
	if (ufp) {
		var hay = [ ufp.class, ufp.device, ufp.vendor, ufp.os, ufp.type ].filter(Boolean).join(' ');
		for (var i = 0; i < NAME_RULES.length; i++)
			if (hay && NAME_RULES[i][1].test(hay)) return [ NAME_RULES[i][0], _('device fingerprint') ];
	}
	if (n)
		for (var j = 0; j < NAME_RULES.length; j++)
			if (NAME_RULES[j][1].test(n)) return [ NAME_RULES[j][0], _('device name “%s”').format(n) ];
	var oui = OUI_MAP[c.mac.replace(/:/g, '').substr(0, 6).toUpperCase()];
	if (oui) return [ oui, _('hardware maker') ];
	if (c.wifi && isPrivateMac(c.mac)) return [ 'phone', _('private Wi-Fi address (typical of phones)') ];
	return c.wifi ? [ 'laptop', _('Wi-Fi device') ] : [ 'desktop', _('wired device') ];
}

/* ---------------------------------------------------------------- helpers */
function fmtRate(bps) {
	if (bps == null) return '';
	if (bps >= 1e9) return (bps / 1e9).toFixed(1) + ' Gbps';
	if (bps >= 1e6) return (bps / 1e6).toFixed(bps >= 1e8 ? 0 : 1) + ' Mbps';
	if (bps >= 1e3) return Math.round(bps / 1e3) + ' kbps';
	return Math.round(bps) + ' bps';
}
function fmtDur(s) {
	if (!s && s !== 0) return '–';
	var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
	return (d ? d + 'd ' : '') + (d || h ? h + 'h ' : '') + m + 'm';
}
function bars(dbm) { return dbm >= -55 ? 4 : dbm >= -65 ? 3 : dbm >= -75 ? 2 : 1; }
function bandName(radio) {
	var b = (radio.config || {}).band || '';
	if (b === '2g') return '2.4 GHz';
	if (b === '5g') return '5 GHz';
	if (b === '6g') return '6 GHz';
	if (b === '60g') return '60 GHz';
	var ch = +((radio.config || {}).channel || 0);
	return ch > 0 && ch <= 14 ? '2.4 GHz' : ch > 14 ? '5 GHz' : _('Wi-Fi');
}
function ip4ToInt(ip) { var p = String(ip).split('.'); return p.length === 4 ? ((+p[0] << 24) >>> 0) + (+p[1] << 16) + (+p[2] << 8) + (+p[3]) : null; }
function inSubnet(ip, net, mask) {
	var a = ip4ToInt(ip), b = ip4ToInt(net);
	if (a == null || b == null) return false;
	var m = mask === 0 ? 0 : (0xffffffff << (32 - mask)) >>> 0;
	return ((a & m) >>> 0) === ((b & m) >>> 0);
}
function flowClass(bps) {
	if (!bps || bps < 8000) return 'idle';
	if (bps < 1e6) return 'low';
	if (bps < 2e7) return 'mid';
	return 'high';
}

return view.extend({
	interval: 5,
	animate: true,
	prev: {},       /* byte counters from the previous refresh, for rates */
	wifiIfs: [],    /* AP interface names learned on the previous refresh */
	sig: '',        /* topology signature: rebuild DOM only when it changes */
	ufp: null,
	tick: 0,

	load: function() {
		return Promise.all([
			uci.load('uniwrt').catch(function() {}),
			L.resolveDefault(callBoard(), {})
		]);
	},

	overrides: function() {
		var o = {};
		uci.sections('uniwrt', 'host').forEach(function(s) {
			if (s.mac) o[s.mac.toUpperCase()] = { icon: s.icon || null, name: s.name || null, sid: s['.name'] };
		});
		return o;
	},

	fetch: function() {
		var self = this, calls = [
			L.resolveDefault(callHints(), {}),
			L.resolveDefault(callWifi(), {}),
			L.resolveDefault(callNetDevs(), {}),
			L.resolveDefault(callIfDump(), [])
		];
		/* station lists for the AP interfaces we already know (same batch) */
		self.wifiIfs.forEach(function(ifn) { calls.push(L.resolveDefault(callAssoc(ifn), [])); });
		/* optional fingerprinting service, if the user installed it — rarely */
		if (L.hasSystemFeature('ufpd') && self.tick % 12 === 0)
			calls.push(L.resolveDefault(callUfp(), {}).then(function(r) { self.ufp = r; }));
		self.tick++;
		return Promise.all(calls).then(function(r) {
			var assoc = {};
			self.wifiIfs.forEach(function(ifn, i) { assoc[ifn] = r[4 + i] || []; });
			return { hints: r[0], wifi: r[1], devs: r[2], ifaces: r[3], assoc: assoc, t: Date.now() / 1000 };
		});
	},

	rate: function(key, bytes, t) {
		var p = this.prev[key], r = null;
		if (p && t > p.t && bytes >= p.b) r = (bytes - p.b) * 8 / (t - p.t);
		this.prev[key] = { b: bytes, t: t };
		return r;
	},

	model: function(d, board) {
		var self = this, ov = this.overrides(), ufp = this.ufp || {};
		var devs = d.devs || {}, t = d.t;

		/* WAN = interfaces holding a default route; the rest with IPv4 are local networks */
		var wan = null, nets = [];
		(d.ifaces || []).forEach(function(i) {
			if (i.interface === 'loopback' || !i.up) return;
			var isWan = (i.route || []).some(function(r) { return r.target === '0.0.0.0' && r.mask === 0; });
			if (isWan && !wan) wan = i;
			else if (!isWan) (i['ipv4-address'] || []).forEach(function(a) { nets.push({ name: i.interface, addr: a.address, mask: a.mask, dev: i.l3_device || i.device }); });
		});

		var ownMacs = {};
		Object.keys(devs).forEach(function(k) { if (devs[k].mac) ownMacs[devs[k].mac.toUpperCase()] = true; });

		var wanDev = wan ? devs[wan.l3_device || wan.device] : null;
		var wanRate = wanDev && wanDev.stats ? self.rate('wan', (wanDev.stats.rx_bytes || 0) + (wanDev.stats.tx_bytes || 0), t) : null;

		/* Wi-Fi networks (AP interfaces) and their stations */
		var groups = [], seen = {}, ifs = [];
		Object.keys(d.wifi || {}).sort().forEach(function(rname) {
			var radio = d.wifi[rname];
			(radio.interfaces || []).forEach(function(w) {
				var cfg = w.config || {};
				if (!w.ifname || (cfg.mode && cfg.mode !== 'ap')) return;
				ifs.push(w.ifname);
				var g = { id: 'wifi:' + w.ifname, kind: 'wifi', title: cfg.ssid || (w.iwinfo || {}).ssid || w.ifname,
				          sub: bandName(radio), up: radio.up !== false && !cfg.disabled, clients: [], rate: 0 };
				(d.assoc[w.ifname] || []).forEach(function(s) {
					var mac = String(s.mac).toUpperCase();
					var bytes = ((s.rx || {}).bytes || 0) + ((s.tx || {}).bytes || 0);
					var r = self.rate('sta:' + mac, bytes, t);
					seen[mac] = true;
					g.clients.push({ mac: mac, wifi: true, signal: s.signal, conn: s.connected_time, inactive: s.inactive,
					                 txr: (s.tx || {}).rate, rxr: (s.rx || {}).rate, rate: r });
					g.rate += r || 0;
				});
				groups.push(g);
			});
		});
		self.wifiIfs = ifs;

		/* wired networks: hosts in a local subnet that aren't Wi-Fi stations or the router itself */
		var wired = {};
		nets.forEach(function(n) {
			if (!wired[n.name]) {
				var dev = devs[n.dev] || {};
				var ports = ((board.network || {})[n.name] || {}).ports || dev.ports || [];
				var rate = 0;
				ports.forEach(function(p) { var pd = devs[p]; if (pd && pd.stats && !pd.wireless) rate += self.rate('port:' + p, (pd.stats.rx_bytes || 0) + (pd.stats.tx_bytes || 0), t) || 0; });
				wired[n.name] = { id: 'net:' + n.name, kind: 'wired', title: n.name === 'lan' ? _('LAN') : n.name.toUpperCase(),
				                  sub: n.addr + '/' + n.mask, up: true, clients: [], rate: rate,
				                  ports: ports.filter(function(p) { var pd = devs[p]; return pd && !pd.wireless && p.indexOf('phy') !== 0 && p.indexOf('wlan') !== 0; })
				                              .map(function(p) { var pd = devs[p]; return { name: p, up: pd.link ? !!pd.link.carrier : !!pd.up, speed: pd.link && pd.link.speed }; }) };
			}
		});

		var clients = {};
		Object.keys(d.hints || {}).forEach(function(m) {
			var mac = m.toUpperCase(), h = d.hints[m];
			if (ownMacs[mac]) return;
			var ip = (h.ipaddrs || [])[0], net = null;
			for (var i = 0; i < nets.length && ip; i++) if (inSubnet(ip, nets[i].addr, nets[i].mask)) { net = nets[i].name; break; }
			clients[mac] = { name: h.name || null, ips: h.ipaddrs || [], ip6s: h.ip6addrs || [], net: net };
			if (!seen[mac] && net && wired[net]) wired[net].clients.push({ mac: mac, wifi: false });
		});
		Object.keys(wired).forEach(function(k) { groups.push(wired[k]); });

		/* fill in names, icons and labels */
		var total = 0, nwifi = 0;
		groups.forEach(function(g) {
			g.clients.forEach(function(c) {
				var h = clients[c.mac] || {}, o = ov[c.mac] || {};
				c.host = h.name; c.ips = h.ips || []; c.ip6s = h.ip6s || [];
				var guess = classify({ mac: c.mac, name: h.name, wifi: c.wifi }, ufp[c.mac] || ufp[c.mac.toLowerCase()]);
				c.auto = guess[0]; c.reason = guess[1];
				c.type = o.icon && ICONS[o.icon] ? o.icon : c.auto;
				c.custom = !!o.icon;
				c.label = o.name || h.name || c.ips[0] || c.mac;
				c.customName = o.name || '';
				c.sid = o.sid;
				total++; if (c.wifi) nwifi++;
			});
			g.clients.sort(function(a, b) { return (b.rate || 0) - (a.rate || 0) || String(a.label).localeCompare(b.label); });
		});

		return { wan: wan, wanRate: wanRate, groups: groups, total: total, nwifi: nwifi };
	},

	/* --------------------------------------------------------------- render */
	render: function(data) {
		var self = this;

		/* the map's styles ship with the UniWRT theme; if another theme is
		   active, say so instead of drawing an unstyled page (and poll nothing) */
		if (!document.querySelector('link[rel="stylesheet"][href*="/uniwrt/css/cascade.css"]'))
			return E('div', {}, [ E('h2', {}, [ _('Network Map') ]),
				E('div', { 'class': 'cbi-map-descr' }, [ _('The Network Map is part of the UniWRT theme. Switch to UniWRT under System → System → Language and Style to use it.') ]) ]);

		this.board = data[1] || {};
		var iv = parseInt(uci.get('uniwrt', 'global', 'netmap_interval'), 10);
		this.interval = isNaN(iv) ? 5 : Math.min(60, Math.max(3, iv));   /* 3–60 s; junk → default */
		this.animate = uci.get('uniwrt', 'global', 'netmap_animate') !== '0';

		this.root = E('div', { 'class': 'u-nm' + (this.animate ? '' : ' u-nm-still') }, [
			E('div', { 'class': 'u-nm-bar' }, [
				E('div', { 'class': 'u-nm-summary', 'id': 'u-nm-summary' }, [ _('Collecting data…') ]),
				E('div', { 'class': 'u-nm-legend' }, [
					E('span', { 'class': 'u-nm-dot u-nm-dot-on' }), _('active'),
					E('span', { 'class': 'u-nm-dot' }), _('idle')
				])
			]),
			E('div', { 'class': 'u-nm-tree', 'id': 'u-nm-tree' })
		]);

		var refresh = function() {
			if (document.hidden) return Promise.resolve();   /* no router work while the tab is hidden */
			return self.fetch().then(function(d) {
				/* first refresh learns the AP interfaces; fetch their stations right away */
				if (!self.learned) { self.learned = true; if (self.wifiIfs.length === 0) { self.model(d, self.board); return self.fetch(); } }
				return d;
			}).then(function(d) { self.lastData = d; self.update(self.model(d, self.board)); });
		};
		refresh();
		poll.add(refresh, this.interval);

		var t;
		window.addEventListener('resize', function() { clearTimeout(t); t = setTimeout(function() { self.links(); }, 120); });
		return E('div', {}, [ E('h2', {}, [ _('Network Map') ]),
			E('div', { 'class': 'cbi-map-descr' }, [ _('Live view of the devices connected to this router. Tap a device to see details or change its icon.') ]),
			this.root ]);
	},

	update: function(m) {
		this.last = m;
		var sum = document.getElementById('u-nm-summary');
		if (sum) sum.textContent = _('%d devices · %d Wi-Fi · %d wired').format(m.total, m.nwifi, m.total - m.nwifi)
			+ (m.wanRate != null ? '  ·  ' + _('Internet %s').format(fmtRate(m.wanRate)) : '');

		var sig = m.groups.map(function(g) { return g.id + ':' + g.clients.map(function(c) { return c.mac + c.type + c.label; }).join(','); }).join('|') + (m.wan ? 'w' : '');
		if (sig !== this.sig) { this.sig = sig; this.build(m); }
		else this.refreshValues(m);
	},

	build: function(m) {
		var self = this, tree = document.getElementById('u-nm-tree');
		if (!tree) return;
		var rows = Math.max(1, m.groups.length);
		var kids = [ (function() { var s = document.createElementNS('http://www.w3.org/2000/svg', 'svg'); s.setAttribute('class', 'u-nm-links'); s.setAttribute('aria-hidden', 'true'); return s; })() ];

		var wan = m.wan || {};
		/* Internet above the router in the first column keeps the device lists wide */
		kids.push(E('div', { 'class': 'u-nm-core', 'style': 'grid-row:1 / span ' + rows }, [
			E('div', { 'class': 'u-nm-node u-nm-inet' + (m.wan ? '' : ' is-down'), 'data-node': 'inet' }, [
				icon('internet', 'u-nm-node-ico'),
				E('div', { 'class': 'u-nm-node-title' }, [ _('Internet') ]),
				E('div', { 'class': 'u-nm-node-sub' }, [ m.wan ? ((wan['ipv4-address'] || [])[0] || {}).address || wan.proto : _('Offline') ]),
				E('div', { 'class': 'u-nm-node-rate', 'data-rate': 'inet' }, [ fmtRate(m.wanRate) ])
			]),
			E('div', { 'class': 'u-nm-node u-nm-router', 'data-node': 'router' }, [
				icon('router', 'u-nm-node-ico'),
				E('div', { 'class': 'u-nm-node-title' }, [ (this.board.model || {}).name || 'OpenWrt' ]),
				E('div', { 'class': 'u-nm-node-sub' }, [ _('Router') ])
			])
		]));

		m.groups.forEach(function(g, i) {
			var head = [ icon(g.kind === 'wifi' ? 'wifi' : 'wired', 'u-nm-node-ico'),
				E('div', { 'class': 'u-nm-node-title' }, [ g.title ]),
				E('div', { 'class': 'u-nm-node-sub' }, [ g.sub + ' · ' + _('%d devices').format(g.clients.length) ]),
				E('div', { 'class': 'u-nm-node-rate', 'data-rate': g.id }, [ fmtRate(g.rate) ]) ];
			if (g.ports && g.ports.length)
				head.push(E('div', { 'class': 'u-nm-ports' }, g.ports.map(function(p) {
					return E('span', { 'class': 'u-nm-port' + (p.up ? ' is-up' : ''), 'title': p.name + (p.up && p.speed ? ' · ' + p.speed + ' Mbps' : p.up ? '' : ' · ' + _('no link')) }, [ p.name ]);
				})));
			kids.push(E('div', { 'class': 'u-nm-node u-nm-group' + (g.up ? '' : ' is-down'), 'data-node': g.id, 'style': 'grid-row:' + (i + 1) }, head));

			kids.push(E('div', { 'class': 'u-nm-lane', 'data-lane': g.id, 'style': 'grid-row:' + (i + 1) },
				g.clients.length ? g.clients.map(function(c) { return self.chip(c); })
				                 : [ E('div', { 'class': 'u-nm-empty' }, [ _('No devices') ]) ]));
		});

		tree.replaceChildren.apply(tree, kids);
		/* layout must settle before measuring for the connecting lines */
		window.requestAnimationFrame(function() { self.links(); });
		if (!this.ro && window.ResizeObserver) {
			this.ro = new ResizeObserver(function() { window.requestAnimationFrame(function() { self.links(); }); });
			this.ro.observe(tree);
		}
	},

	chip: function(c) {
		var self = this;
		/* second line: the IP, or the MAC when the IP is already the name */
		var sub = c.ips[0] && c.ips[0] !== c.label ? c.ips[0] : c.mac;
		var b = E('button', { 'type': 'button', 'class': 'u-nm-client', 'data-mac': c.mac,
			'title': c.label + ' — ' + (TYPE_NAME[c.type] || '') }, [
			icon(c.type),
			E('span', { 'class': 'u-nm-client-text' }, [
				E('span', { 'class': 'u-nm-client-name' }, [ c.label ]),
				E('span', { 'class': 'u-nm-client-sub' }, [ sub ])
			]),
			E('span', { 'class': 'u-nm-client-meta' }, [
				c.wifi ? E('span', { 'class': 'u-nm-bars b' + bars(c.signal), 'title': c.signal + ' dBm' }, [ E('i'), E('i'), E('i'), E('i') ]) : '',
				E('span', { 'class': 'u-nm-client-rate', 'data-mac-rate': c.mac }, [ c.rate >= 8000 ? fmtRate(c.rate) : '' ])
			]),
			E('span', { 'class': 'u-nm-act' + (c.rate >= 8000 ? ' is-on' : ''), 'data-act': c.mac })
		]);
		b.addEventListener('click', function() { self.details(c.mac); });
		return b;
	},

	refreshValues: function(m) {
		var root = this.root;
		var set = function(sel, txt) { var e = root.querySelector(sel); if (e && e.textContent !== txt) e.textContent = txt; };
		set('[data-rate="inet"]', fmtRate(m.wanRate));
		m.groups.forEach(function(g) {
			set('[data-rate="' + g.id + '"]', fmtRate(g.rate));
			g.clients.forEach(function(c) {
				set('[data-mac-rate="' + c.mac + '"]', c.rate >= 8000 ? fmtRate(c.rate) : '');
				var a = root.querySelector('[data-act="' + c.mac + '"]'); if (a) a.classList.toggle('is-on', c.rate >= 8000);
			});
		});
		this.flows(m);
	},

	/* connecting lines: measured from the laid-out cards, drawn once per layout */
	links: function() {
		var tree = document.getElementById('u-nm-tree'), m = this.last;
		if (!tree || !m) return;
		/* on a map taller than the screen, keep Internet/router at the top
		   instead of centred halfway down the page */
		tree.classList.toggle('u-nm-tall', tree.offsetHeight > window.innerHeight * 0.9);
		var svg = tree.querySelector('svg.u-nm-links'), box = tree.getBoundingClientRect();
		if (!svg) return;
		svg.setAttribute('width', box.width); svg.setAttribute('height', box.height);
		svg.setAttribute('viewBox', '0 0 ' + box.width + ' ' + box.height);
		var node = function(sel) { var e = tree.querySelector(sel); if (!e) return null; var r = e.getBoundingClientRect();
			return { l: r.left - box.left, r: r.right - box.left, t: r.top - box.top, b: r.bottom - box.top, cx: r.left - box.left + r.width / 2, cy: r.top - box.top + r.height / 2 }; };
		var path = function(a, b) {
			if (b.l >= a.r - 4) {   /* side by side (desktop) */
				var x1 = a.r, y1 = a.cy, x2 = b.l, y2 = b.cy, k = Math.max(24, (x2 - x1) / 2);
				return 'M' + x1 + ' ' + y1 + ' C' + (x1 + k) + ' ' + y1 + ' ' + (x2 - k) + ' ' + y2 + ' ' + x2 + ' ' + y2;
			}
			var X1 = Math.min(a.l + 22, a.cx), Y1 = a.b, X2 = Math.min(b.l + 22, b.cx), Y2 = b.t, K = Math.max(14, (Y2 - Y1) / 2);   /* stacked (phones) */
			return 'M' + X1 + ' ' + Y1 + ' C' + X1 + ' ' + (Y1 + K) + ' ' + X2 + ' ' + (Y2 - K) + ' ' + X2 + ' ' + Y2;
		};
		var out = [], inet = node('[data-node="inet"]'), rt = node('[data-node="router"]');
		if (inet && rt) out.push([ 'inet', path(inet, rt) ]);
		m.groups.forEach(function(g) {
			var gn = node('[data-node="' + g.id + '"]'), ln = node('[data-lane="' + g.id + '"]');
			if (rt && gn) out.push([ g.id, path(rt, gn) ]);
			if (gn && ln) out.push([ g.id + ':lane', path(gn, ln) ]);
		});
		var NS = 'http://www.w3.org/2000/svg';
		var frag = document.createDocumentFragment();
		out.forEach(function(o) {
			var base = document.createElementNS(NS, 'path'); base.setAttribute('d', o[1]); base.setAttribute('class', 'u-nm-wire');
			var flow = document.createElementNS(NS, 'path'); flow.setAttribute('d', o[1]); flow.setAttribute('class', 'u-nm-flow idle'); flow.setAttribute('data-flow', o[0]);
			frag.appendChild(base); frag.appendChild(flow);
		});
		svg.replaceChildren(frag);
		this.flows(m);
	},

	flows: function(m) {
		var root = this.root;
		var set = function(id, bps, down) { var p = root.querySelector('[data-flow="' + id + '"]'); if (p) p.setAttribute('class', 'u-nm-flow ' + (down ? 'down' : flowClass(bps))); };
		set('inet', m.wanRate, !m.wan);
		m.groups.forEach(function(g) { set(g.id, g.rate, !g.up); set(g.id + ':lane', g.rate, !g.up); });
	},

	/* ------------------------------------------------------- device panel */
	findClient: function(mac) {
		var r = null;
		(this.last ? this.last.groups : []).forEach(function(g) { g.clients.forEach(function(c) { if (c.mac === mac) r = { c: c, g: g }; }); });
		return r;
	},

	details: function(mac) {
		var self = this, f = this.findClient(mac);
		if (!f) return;
		var c = f.c, g = f.g, chosen = c.custom ? c.type : '';
		var nameInput = E('input', { 'type': 'text', 'class': 'cbi-input-text', 'value': c.customName, 'placeholder': c.host || c.ips[0] || c.mac, 'maxlength': 48 });
		var row = function(k, v) { return v ? E('div', { 'class': 'u-nm-kv' }, [ E('span', {}, [ k ]), E('span', {}, [ v ]) ]) : ''; };
		var preview = E('div', { 'class': 'u-nm-detail-ico' }, [ icon(c.type) ]);

		var tiles = E('div', { 'class': 'u-nm-icons', 'role': 'radiogroup', 'aria-label': _('Device icon') });
		var mk = function(type, label, ico) {
			var t = E('button', { 'type': 'button', 'class': 'u-nm-icon-tile' + (chosen === type ? ' is-sel' : ''), 'role': 'radio', 'aria-checked': chosen === type ? 'true' : 'false', 'data-type': type, 'title': label }, [ icon(ico), E('span', {}, [ label ]) ]);
			t.addEventListener('click', function() {
				chosen = type;
				tiles.querySelectorAll('.u-nm-icon-tile').forEach(function(x) { var on = x.getAttribute('data-type') === type; x.classList.toggle('is-sel', on); x.setAttribute('aria-checked', on ? 'true' : 'false'); });
				preview.replaceChildren(icon(type || c.auto));
			});
			return t;
		};
		tiles.appendChild(mk('', _('Auto') + ' (' + (TYPE_NAME[c.auto] || '') + ')', c.auto));
		TYPES.forEach(function(t) { tiles.appendChild(mk(t[0], t[1], t[0])); });

		var via = c.wifi ? g.title + ' · ' + g.sub : g.title + _(' (wired)');
		ui.showModal(c.label, [
			E('div', { 'class': 'u-nm-detail' }, [
				preview,
				E('div', { 'class': 'u-nm-detail-info' }, [
					row(_('Connected via'), via),
					row(_('IPv4'), c.ips.join(', ')),
					row(_('IPv6'), c.ip6s.slice(0, 2).join(', ')),
					row(_('MAC'), c.mac + (isPrivateMac(c.mac) ? ' · ' + _('private address') : '')),
					c.wifi ? row(_('Signal'), c.signal + ' dBm') : '',
					c.wifi && c.txr ? row(_('Link rate'), fmtRate(c.txr * 1000) + ' ↓ / ' + fmtRate(c.rxr * 1000) + ' ↑') : '',
					c.wifi ? row(_('Connected for'), fmtDur(c.conn)) : '',
					row(_('Traffic now'), c.wifi ? (fmtRate(c.rate) || '–') : _('shown per port for wired devices')),
					row(_('Detected as'), (TYPE_NAME[c.auto] || '') + ' — ' + c.reason)
				])
			]),
			E('label', { 'class': 'u-nm-field' }, [ E('span', {}, [ _('Name') ]), nameInput ]),
			E('div', { 'class': 'u-nm-field' }, [ E('span', {}, [ _('Icon') ]), tiles ]),
			E('div', { 'class': 'right' }, [
				E('button', { 'class': 'btn cbi-button', 'click': ui.hideModal }, [ _('Cancel') ]), ' ',
				E('button', { 'class': 'btn cbi-button-positive important', 'click': ui.createHandlerFn(this, function() {
					return self.save(c, nameInput.value.trim(), chosen);
				}) }, [ _('Save') ])
			])
		], 'u-nm-modal');
	},

	/* names and icons live in /etc/config/uniwrt (kept across upgrades); a
	   direct uci commit means nothing restarts and no apply countdown runs */
	save: function(c, name, type) {
		var self = this, sid = c.sid || ('h_' + c.mac.replace(/:/g, '').toLowerCase());
		return uci.load('uniwrt').then(function() {
			if (!name && !type) {
				if (uci.get('uniwrt', sid)) uci.remove('uniwrt', sid);
			} else {
				if (!uci.get('uniwrt', sid)) uci.add('uniwrt', 'host', sid);
				uci.set('uniwrt', sid, 'mac', c.mac);
				uci.set('uniwrt', sid, 'name', name || null);
				uci.set('uniwrt', sid, 'icon', type || null);
			}
			return uci.save();
		}).then(function() {
			return callCommit('uniwrt');
		}).then(function() {
			uci.unload('uniwrt');
			return uci.load('uniwrt');
		}).then(function() {
			ui.hideModal();
			if (ui.changes && ui.changes.init) ui.changes.init();
			self.sig = '';   /* force a rebuild with the new label/icon */
			if (self.lastData) self.update(self.model(self.lastData, self.board));
		}).catch(function(e) {
			ui.addNotification(null, E('p', [ _('Could not save: %s').format(e.message || e) ]), 'error');
		});
	},

	handleSaveApply: null, handleSave: null, handleReset: null
});
