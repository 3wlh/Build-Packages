# Copyright (C) 2020-2026 3wlh <https://github.com/3wlh>
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-subscribe
PKG_VERSION:=$(shell date +%y.%m.%d)
PKG_RELEASE:=$(shell date +%H%M%S)
PKG_MAINTAINER:=3wlh <3wlh.lh@gmail.com>
LUCI_TITLE:=LuCI app for subscribe
LUCI_LANG:=zh-cn

PKG_BUILD_DIR:=$(BUILD_DIR)/PKG_BUILD_$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=Applications
	TITLE:=$(PKG_NAME)
	URL:=https://github.com/3wlh
	PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
	A lightweight self-hosted subscription server that generates VLESS/VMess/SOCKS links, for OpenWrt.
endef

define Build/Po2lmo
	if ! command -v po2lmo >/dev/null 2>&1; then \
		git clone https://github.com/openwrt-dev/po2lmo.git && cd po2lmo; \
		make clean && make && make install PREFIX=/tmp/ && cd - ;\
	fi
	$(foreach po,$(wildcard ./po/zh-cn/*.po), \
		/tmp/po2lmo $(po) $(PKG_BUILD_DIR)/$(patsubst %.po,%.lmo,$(notdir $(po)));)
endef

define Build/Prepare
	mkdir -pm 775 $(PKG_BUILD_DIR)
	$(call Build/Po2lmo)
	$(CP) -fr root $(PKG_BUILD_DIR)
	$(CP) -fr luasrc $(PKG_BUILD_DIR)
	$(CP) -fr scripts $(PKG_BUILD_DIR)
	chmod -R 755 $(PKG_BUILD_DIR)
	ls $(PKG_BUILD_DIR)
endef

define Package/$(PKG_NAME)/postinst
[ -n "$${IPKG_INSTROOT}" ] || { rm -f /tmp/luci-indexcache.*
	rm -rf /tmp/luci-modulecache/
	/etc/init.d/rpcd reload 2>/dev/null
	/etc/init.d/ucitrack reload 2>/dev/null
	exit 0
}
endef

# 卸载前: 停止并禁用服务 (此时 init 脚本和二进制仍在, 可正常 stop)
define Package/$(PKG_NAME)/prerm
[ -n "$${IPKG_INSTROOT}" ] || { /etc/init.d/subscribe stop 2>/dev/null
	/etc/init.d/subscribe disable 2>/dev/null
	exit 0
}
endef

# 卸载后: 删除 opkg (不跟踪的残留文件),
define Package/$(PKG_NAME)/postrm
[ -n "$${IPKG_INSTROOT}" ] || { rm -f /usr/sbin/subscribe
	rm -f /tmp/luci-indexcache.*
	rm -rf /tmp/luci-modulecache/
	/etc/init.d/rpcd reload 2>/dev/null
	/etc/init.d/ucitrack reload 2>/dev/null
	exit 0
}
endef

define Build/Compile
	touch $(BUILD_DIR)/$(PKG_NAME).built
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/subscribe
endef

define Package/$(PKG_NAME)/install
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/*.*.lmo $(1)/usr/lib/lua/luci/i18n/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/subscribe.init $(1)/etc/init.d/subscribe
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/subscribe.config $(1)/etc/config/subscribe
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/subscribe.uci-default $(1)/etc/uci-defaults/99-$(PKG_NAME)

endef

# call BuildPackage - OpenWrt buildroot signature
$(eval $(call BuildPackage,$(PKG_NAME)))