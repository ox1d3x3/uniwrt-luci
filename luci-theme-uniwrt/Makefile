# SPDX-License-Identifier: MIT
#
# luci-theme-uniwrt — a UniWRT-styled theme for OpenWrt LuCI
#
# Architecture-independent ("all"): one build works on every OpenWrt target.
# Builds as .ipk on 23.05 / 24.10 (opkg) and as .apk on 25.12+ (apk) — the
# package format is chosen automatically by whichever SDK builds it.

include $(TOPDIR)/rules.mk

LUCI_TITLE:=UniWRT theme for LuCI
LUCI_DESCRIPTION:=UniWRT — a clean, card-based LuCI theme: left icon rail, \
  soft shadows, rounded surfaces, pill controls and automatic light/dark \
  modes. Architecture-independent; works on any OpenWrt target.
# We inherit the stock bootstrap chrome (menu / i18n / theme machinery) and
# restyle it, so bootstrap must be present.
LUCI_DEPENDS:=+luci-theme-bootstrap
LUCI_PKGARCH:=all

PKG_VERSION:=1.4.1
# PKG_RELEASE is set from the CI build number when built in Actions; falls
# back to 1 for local builds.
PKG_RELEASE:=$(if $(THEME_RELEASE),$(THEME_RELEASE),1)

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Your Name <you@example.com>

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
