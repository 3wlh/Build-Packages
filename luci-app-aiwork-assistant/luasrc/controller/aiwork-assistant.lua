module(..., package.seeall)
local name = (...):match("%.([^%.]+)$")
module("luci.controller."..name, package.seeall)

function index()
	-- 菜单始终注册 (二进制检查在 action_index 实时执行, 避免菜单缓存导致下载后不刷新)
	entry({"admin", "services", name}, firstchild(), _("AI助手"), 90).dependent = true
	entry({"admin", "services",name.."_status"}, call("Run_status")).leaf = true
	-- 注册菜单 --
	entry({"admin", "services", name, "settings"}, cbi(name.."/settings"), _("配置设置"), 10).leaf = true
end

function Run_status()
	luci.http.prepare_content("application/json")
	local uci  = require "luci.model.uci".cursor()
	local port = tonumber(uci:get(name, "config", "port"))
	local cmd = string.format("pgrep %s* >/dev/null", name)
	local status = {
		running = (luci.sys.call(cmd) == 0),
		port = (port or 7864)
	}
	luci.http.write_json(status)
end