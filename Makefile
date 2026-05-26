# SPDX-License-Identifier: Apache-2.0

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-uniwrt
PKG_VERSION:=0.1.7
PKG_RELEASE:=1
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=Mahabub X <mgrsubhany7@gmail.com>

LUCI_NAME:=luci-theme-uniwrt
LUCI_TITLE:=UniWRT Theme
LUCI_DEPENDS:=+luci-base +luci-theme-bootstrap
LUCI_DESCRIPTION:=UniWRT is a clean, modern, responsive LuCI theme for OpenWrt 24.x and 25.x.
LUCI_MAINTAINER:=Mahabub X <mgrsubhany7@gmail.com>
LUCI_PKGARCH:=all
LUCI_MINIFY_JS:=0
LUCI_MINIFY_CSS:=0

define Package/luci-theme-uniwrt/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	uci -q delete luci.themes.UniWRT
	uci -q delete luci.themes.UniWRTDark
	uci -q delete luci.themes.UniWRTLight
	uci commit luci
}
endef

LUCI_MK:=$(firstword $(wildcard ../../luci.mk $(TOPDIR)/feeds/luci/luci.mk))
ifeq ($(LUCI_MK),)
  $(error Unable to locate luci.mk. Run scripts/build-sdk.sh or place this package inside the LuCI feed themes directory.)
endif

include $(LUCI_MK)

# call BuildPackage - OpenWrt buildroot signature
