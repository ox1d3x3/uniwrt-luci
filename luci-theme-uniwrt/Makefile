# SPDX-License-Identifier: MIT
#
# luci-theme-uniwrt — a UniWRT-styled theme for OpenWrt LuCI
#
# Architecture-independent ("all"): one build works on every OpenWrt target.
# Builds as .ipk on 23.05/24.10 (opkg) and as .apk on 25.12+ (apk) — the
# package format is chosen automatically by whichever SDK builds it.

include $(TOPDIR)/rules.mk

LUCI_TITLE:=UniWRT Portal theme for LuCI
LUCI_DESCRIPTION:=UniWRT Portal — a modern OpenWrt LuCI theme with a controller-style left rail, \
  responsive mobile drawer, rounded cards, clean table/form treatment, light/dark \
  modes and original UniWRT branding. Architecture-independent; works on any \
  OpenWrt target.
# We inherit the stock bootstrap chrome (menu / i18n / theme machinery) and
# restyle it, so bootstrap must be present.
LUCI_DEPENDS:=+luci-base +luci-theme-bootstrap
LUCI_PKGARCH:=all

PKG_VERSION:=2.0.9
# PKG_RELEASE is set from the CI build number when built in Actions; falls
# back to 1 for local builds.
PKG_RELEASE:=$(if $(THEME_RELEASE),$(THEME_RELEASE),1)

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Mahabub X <github.com/ox1d3x3>

# Keep modern CSS untouched; LuCI csstidy can break modern selectors/variables.
LUCI_MINIFY_CSS:=
CONFIG_LUCI_CSSTIDY:=

define Package/luci-theme-uniwrt/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	uci -q delete luci.themes.UniWRT
	if [ "$$(uci -q get luci.main.mediaurlbase)" = "/luci-static/uniwrt" ]; then
		uci -q set luci.main.mediaurlbase="/luci-static/bootstrap"
	fi
	uci -q commit luci
	rm -rf /tmp/luci-indexcache /tmp/luci-modulecache 2>/dev/null
}
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
