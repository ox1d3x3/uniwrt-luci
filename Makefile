# SPDX-License-Identifier: Apache-2.0
#
# CleanX LuCI Theme
#
# v0.2.5 build fix:
# - Uses the normal LuCI package helper through $(TOPDIR)/feeds/luci/luci.mk
# - Requires the workflow to run scripts/feeds update/install first
# - Works from package/custom/luci-theme-cleanx inside the OpenWrt SDK
# - Generates IPK on OpenWrt 24.10.x SDK and APK on OpenWrt 25.x/snapshot SDK

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-cleanx
PKG_VERSION:=0.2.5
PKG_RELEASE:=1
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=Mahabub X <mgrsubhany7@gmail.com>

LUCI_TITLE:=CleanX LuCI Theme
LUCI_DESCRIPTION:=CleanX is a clean, modern and responsive LuCI theme for OpenWrt.
LUCI_DEPENDS:=+luci-base

define Package/luci-theme-cleanx/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	uci -q delete luci.themes.CleanX
	uci -q delete luci.themes.UniWRT
	uci -q delete luci.themes.X1Wrt
	uci commit luci
	rm -f /tmp/luci-indexcache.*
	rm -rf /tmp/luci-modulecache/
}
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
