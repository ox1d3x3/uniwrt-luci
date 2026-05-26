# SPDX-License-Identifier: Apache-2.0
#
# CleanX LuCI Theme
#
# v0.2.3 package build fix:
# - Static theme package only
# - No luci.mk
# - No DEPENDS that force LuCI runtime packages to compile inside SDK
# - Builds as .ipk on OpenWrt 24.10 SDK
# - Builds as .apk on OpenWrt 25.12+ SDK

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-cleanx
PKG_VERSION:=0.2.3
PKG_RELEASE:=1
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=Mahabub X <mgrsubhany7@gmail.com>
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/luci-theme-cleanx
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=4. Themes
  TITLE:=CleanX LuCI Theme
endef

define Package/luci-theme-cleanx/description
  CleanX is a clean, modern and responsive LuCI theme for OpenWrt.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-theme-cleanx/install
	$(INSTALL_DIR) $(1)/www/luci-static/cleanx
	$(CP) ./htdocs/luci-static/cleanx/* $(1)/www/luci-static/cleanx/

	$(INSTALL_DIR) $(1)/usr/share/ucode/luci/template/themes/cleanx
	$(CP) ./ucode/template/themes/cleanx/* $(1)/usr/share/ucode/luci/template/themes/cleanx/

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/30_luci-theme-cleanx $(1)/etc/uci-defaults/30_luci-theme-cleanx
endef

define Package/luci-theme-cleanx/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	[ -x /etc/uci-defaults/30_luci-theme-cleanx ] && /etc/uci-defaults/30_luci-theme-cleanx || true
	rm -rf /tmp/luci-indexcache /tmp/luci-modulecache 2>/dev/null || true
}
exit 0
endef

define Package/luci-theme-cleanx/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	uci -q delete luci.themes.CleanX
	uci -q delete luci.themes.UniWRT
	uci -q delete luci.themes.X1Wrt
	uci commit luci
	rm -rf /tmp/luci-indexcache /tmp/luci-modulecache 2>/dev/null || true
}
exit 0
endef

$(eval $(call BuildPackage,luci-theme-cleanx))
