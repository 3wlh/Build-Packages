include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-smbvfs
PKG_VERSION:=1.0
PKG_RELEASE:=$(shell date +%Y%m%d)
KG_MAINTAINER:=3wlh <3wlh.lh@gmail.com>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=Applications
	TITLE:=LuCI support for smbvfs
	DEPENDS:=@(aarch64||x86_64)
endef

define Package/$(PKG_NAME)/description
    Apply macOS-compatible vfs fruit options to all Samba shares and keep them applied automatically.
endef

define Build/Prepare
	echo -e "\033[31mARCH：$(PKG_ARCH)\033[0m"
	mkdir -p $(PKG_BUILD_DIR)
	# 复制源码到编译目录（无空格路径）
	chmod -R 755 ./luasrc ./root
	$(CP) ./root $(PKG_BUILD_DIR)
	$(CP) ./luasrc $(PKG_BUILD_DIR)
	$(CP) ./src $(PKG_BUILD_DIR)
endef

define Build/Compile
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_CPPFLAGS) \
		-o $(PKG_BUILD_DIR)/smbvfsd $(PKG_BUILD_DIR)/src/smbvfsd.c $(TARGET_LDFLAGS)
endef

define Package/$(PKG_NAME)/install
	# 手动指定安装路径（绝对路径，无拼接）
	$(INSTALL_DIR) $(1)/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/smbvfsd $(1)/usr/sbin/smbvfsd
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))