# Copyright (C) 2020-2026 3wlh <https://github.com/3wlh>
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-aiwork-assistant
BIN_NAME:=aiwork-assistant
PKG_VERSION:=$(shell date +%y.%m.%d)
PKG_RELEASE:=$(shell date +%H%M%S)
PKG_MAINTAINER:=3wlh <3wlh.lh@gmail.com>
LUCI_TITLE:=LuCI app for aiwork-assistant
LUCI_LANG:=zh-cn

ifeq ($(ARCH),aarch64)
	PKG_ARCH:=arm64
endif
ifeq ($(ARCH),x86_64)
	PKG_ARCH:=amd64
endif

FILE_URL:=https://github.com/3wlh/Build-Source/releases/download/GitHub-Actions_AiWorkAssistant/aiwork-assistant-linux-$(PKG_ARCH).tar.gz
GZ_FILE:=$(BIN_NAME).tar.gz
PKG_BUILD_DIR:=$(BUILD_DIR)/PKG_BUILD_$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=Applications
	TITLE:=$(PKG_NAME)
	URL:=https://github.com/3wlh
	DEPENDS:=@(aarch64||x86_64)
endef

define Package/$(PKG_NAME)/description
	AI Work Assistant - An integrated tool for managing multiple accounts in AI applications.
endef

define Download/Files
	echo -e "\033[32m Download：$(PKG_ARCH) \033[0m"
	if [ ! -f $(PKG_BUILD_DIR)/$(GZ_FILE) ] ; then \
		wget $(FILE_URL) -O $(PKG_BUILD_DIR)/$(GZ_FILE); \
	fi
	ls $(PKG_BUILD_DIR)
endef

define Extract/Files
	echo -e "\033[1;32m Extract：Files \033[0m"
	mkdir -p $(PKG_BUILD_DIR)/Ai-Work-Assistant
	tar -zxf $(PKG_BUILD_DIR)/$(WEB_FILE) -C $(PKG_BUILD_DIR)/Ai-Work-Assistant
endef

define Build/Po2lmo
	if [ ! -d "po2lmo" ]; then \
		git clone https://github.com/openwrt-dev/po2lmo.git && cd po2lmo; \
		make clean && make && make install PREFIX=/tmp/ && cd - ;\
	fi
	$(foreach po,$(wildcard ./po/zh-cn/*.po), \
		/tmp/po2lmo $(po) $(PKG_BUILD_DIR)/$(patsubst %.po,%.lmo,$(notdir $(po)));)
endef

define Build/Prepare
	echo -e "\033[1;32m Prepare：$(PKG_ARCH)\033[0m"
	rm -rf $(PKG_BUILD_DIR)
	mkdir -pm 775 $(PKG_BUILD_DIR)
	$(call Download/Files)
	$(call Extract/Files)
	# $(call Build/Po2lmo)
	$(CP) -fr root $(PKG_BUILD_DIR)
	$(CP) -fr luasrc $(PKG_BUILD_DIR)
	chmod -R 755 $(PKG_BUILD_DIR)
	ls $(PKG_BUILD_DIR)
endef

define Package/$(PKG_NAME)/postinst
[ -n "${IPKG_INSTROOT}" ] || { rm -f /tmp/luci-indexcache.*
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
/etc/config/aiwork-assistant
endef

define Package/$(PKG_NAME)/install
	echo -e "\033[1;32m install \033[0m"
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/Ai-Work-Assistant/aiwork-server $(1)/usr/sbin/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/aiwork-assistant.init $(1)/etc/init.d/aiwork-assistant
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/aiwork-assistant.config $(1)/etc/config/aiwork-assistant
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/aiwork-assistant.uci-default $(1)/etc/uci-defaults/99-$(PKG_NAME)
	$(INSTALL_DIR) $(1)/etc/aiwork-assistant
	$(CP) $(PKG_BUILD_DIR)/Ai-Work-Assistant/web-dist $(1)/etc/aiwork-assistant/

endef


# call BuildPackage - OpenWrt buildroot signature
$(eval $(call BuildPackage,$(PKG_NAME)))