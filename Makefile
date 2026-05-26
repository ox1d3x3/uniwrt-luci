# SPDX-License-Identifier: Apache-2.0
# UniWRT LuCI Theme for OpenWrt 24.x / 25.x

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-uniwrt
PKG_VERSION:=0.1.3
PKG_RELEASE:=1
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=Mahabub X <mgrsubhany7@gmail.com>
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/luci-theme-uniwrt
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=4. Themes
  TITLE:=UniWRT Theme - modern LuCI controller skin
  DEPENDS:=+luci-base +luci-theme-bootstrap
endef

define Package/luci-theme-uniwrt/description
  UniWRT is a clean, modern, responsive LuCI theme for OpenWrt 24.x and 25.x.
  It uses UniWRT branding, a network-controller style layout, smooth motion,
  responsive spacing, and dark/light mode support.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./htdocs $(PKG_BUILD_DIR)/
	$(CP) ./root $(PKG_BUILD_DIR)/
	$(CP) ./ucode $(PKG_BUILD_DIR)/
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-theme-uniwrt/install
	$(INSTALL_DIR) $(1)/www/luci-static/uniwrt
	$(CP) $(PKG_BUILD_DIR)/htdocs/luci-static/uniwrt/* $(1)/www/luci-static/uniwrt/
	$(INSTALL_DIR) $(1)/usr/share/ucode/luci/template/themes/uniwrt
	$(CP) $(PKG_BUILD_DIR)/ucode/template/themes/uniwrt/* $(1)/usr/share/ucode/luci/template/themes/uniwrt/
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/uci-defaults/30_luci-theme-uniwrt $(1)/etc/uci-defaults/30_luci-theme-uniwrt
endef

define Package/luci-theme-uniwrt/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	uci -q delete luci.themes.UniWRT
	uci -q delete luci.themes.UniWRTDark
	uci -q delete luci.themes.UniWRTLight
	uci commit luci
}
endef

$(eval $(call BuildPackage,luci-theme-uniwrt))
