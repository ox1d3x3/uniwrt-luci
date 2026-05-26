#
# Copyright (C) 2026 UniWRT contributors
#
# This is free software, licensed under the Apache License, Version 2.0.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-uniwrt
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=Mahabub X <mgrsubhany7@gmail.com>
PKGARCH:=all

LUCI_TITLE:=UniWRT modern LuCI theme
LUCI_DESCRIPTION:=A clean, animated, controller-style OpenWrt LuCI theme inspired by modern network dashboards.
LUCI_DEPENDS:=+luci-base +luci-theme-bootstrap

# Do not run csstidy. Modern CSS variables, clamp(), :has() fallbacks and animations
# can be damaged by old CSS minifiers in some SDK images.
CONFIG_LUCI_CSSTIDY:=

define Package/luci-theme-uniwrt/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	uci -q delete luci.themes.UniWRT
	uci commit luci
}
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
