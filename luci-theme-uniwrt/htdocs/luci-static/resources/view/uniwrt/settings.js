'use strict';
'require view';
'require form';
'require uci';

return view.extend({
	load: function() {
		return uci.load('uniwrt');
	},

	render: function() {
		var m, s, o;

		m = new form.Map('uniwrt', _('UniWRT Theme'),
			_('Configure the appearance of the UniWRT Portal theme. Changes apply after saving and reloading the page.'));

		/* ---- Appearance ---- */
		s = m.section(form.NamedSection, 'global', 'global', _('Appearance'));
		s.anonymous = true;

		o = s.option(form.ListValue, 'mode', _('Theme mode'),
			_('"Auto" follows your operating system\'s light/dark preference. The header toggle can override this per-browser.'));
		o.value('auto', _('Auto (follow system)'));
		o.value('light', _('Light'));
		o.value('dark', _('Dark'));
		o.default = 'auto';

		o = s.option(form.ListValue, 'font_size', _('Base font size'),
			_('Scales all text in the interface.'));
		o.value('13', _('Small (13px)'));
		o.value('14', _('Normal (14px)'));
		o.value('16', _('Large (16px)'));
		o.value('18', _('Extra large (18px)'));
		o.default = '14';

		o = s.option(form.Flag, 'rail_collapsed', _('Collapse navigation by default'),
			_('Start with the side navigation rail collapsed to icons on desktop.'));
		o.default = '0';
		o.rmempty = false;

		/* ---- Accent colours ---- */
		s = m.section(form.NamedSection, 'global', 'global', _('Accent Colour'));
		s.anonymous = true;

		function colorWidget(section_id) {
			var el = form.Value.prototype.renderWidget.apply(this, arguments);
			var input = el.querySelector('input');
			if (input) { input.type = 'color'; input.style.height = '2.6rem'; input.style.width = '4rem'; input.style.cursor = 'pointer'; input.style.padding = '3px'; }
			return el;
		}

		o = s.option(form.Value, 'accent', _('Accent (light mode)'),
			_('Primary colour for links, active items and buttons in light mode.'));
		o.default = '#006fff';
		o.placeholder = '#006fff';
		o.renderWidget = colorWidget;

		o = s.option(form.Value, 'dark_accent', _('Accent (dark mode)'),
			_('Primary colour for links, active items and buttons in dark mode.'));
		o.default = '#4797ff';
		o.placeholder = '#4797ff';
		o.renderWidget = colorWidget;

		/* ---- Dashboard ---- */
		s = m.section(form.NamedSection, 'global', 'global', _('Dashboard & Status'));
		s.anonymous = true;

		o = s.option(form.Flag, 'status_bar', _('Live header status bar'),
			_('Show CPU, memory, throughput and uptime chips in the header. Disable to reduce polling on low-end devices.'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Flag, 'overview', _('UniWRT Overview page'),
			_('Add a custom live "Overview" dashboard entry to the menu.'));
		o.default = '1';
		o.rmempty = false;

		return m.render();
	}
});
