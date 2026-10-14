#!/bin/sh
# luci-app-smbvfs - 为所有 sambashare 补写 fruit (macOS 兼容) 选项
# 已全部配置则静默退出, 保证幂等
changed=0
for share in $(uci show samba4 2>/dev/null | grep '=sambashare$' | cut -d. -f2 | cut -d= -f1); do
	[ "$(uci -q get "samba4.$share.vfs_objects")" = "catia fruit streams_xattr" ] && continue
	uci set "samba4.$share.vfs_objects=catia fruit streams_xattr"
	uci set "samba4.$share.fruit_metadata=stream"
	uci set "samba4.$share.fruit_model=MacSamba"
	uci set "samba4.$share.fruit_posix_rename=yes"
	uci set "samba4.$share.fruit_delete_emptyadfiles=yes"
	changed=1
done
[ "$changed" = "1" ] || exit 0
uci commit samba4
if [ -x /etc/init.d/samba4 ]; then
	/etc/init.d/samba4 restart
elif [ -x /etc/init.d/samba ]; then
	/etc/init.d/samba restart
fi
logger -t smbvfs "fruit options re-applied"
