// luci-app-smbvfs - 监控 /etc/config/samba4 文件变动 (vi / 直接写文件 / uci commit 均可),
// 等写入方把文件全部改完 (静默 DELAY_SEC 秒) 后才补写 fruit 选项; 由 procd 托管, 前台运行
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <poll.h>
#include <sys/inotify.h>

#define CONF_DIR  "/etc/config"
#define CONF_NAME "samba4"
#define APPLY     "/usr/share/smbvfs/apply.sh >/dev/null 2>&1"
#define DELAY_SEC 3   /* 静默等待: 期间有新事件则重新计时, 保证在其他文件修改完成后才执行 */

int main(void)
{
	int fd = inotify_init1(0);
	if (fd < 0) { perror("inotify_init1"); return 1; }
	if (inotify_add_watch(fd, CONF_DIR, IN_CLOSE_WRITE | IN_MOVED_TO) < 0) {
		perror("inotify_add_watch");
		return 1;
	}

	char buf[16 * (sizeof(struct inotify_event) + NAME_MAX + 1)];
	int pending = 0;
	for (;;) {
		struct pollfd pfd = { .fd = fd, .events = POLLIN };
		int r = poll(&pfd, 1, pending ? DELAY_SEC * 1000 : -1);
		if (r == 0) {          /* 静默超时, 写入方已改完, 执行补写 */
			pending = 0;
			system(APPLY);
			continue;
		}
		if (r < 0 || !(pfd.revents & POLLIN)) continue;
		ssize_t n = read(fd, buf, sizeof(buf));
		for (char *p = buf; n > 0 && p < buf + n; ) {
			struct inotify_event *ev = (struct inotify_event *)p;
			if (ev->len && strcmp(ev->name, CONF_NAME) == 0)
				pending = 1;
			p += sizeof(struct inotify_event) + ev->len;
		}
	}
}
