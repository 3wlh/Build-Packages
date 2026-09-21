module(..., package.seeall)
local name = (...):match("%.([^%.]+)$")
module("luci.controller."..name, package.seeall)
local api = require("luci.model.cbi."..name..".api.download")

function index()
	-- 菜单始终注册 (二进制检查在 action_index 实时执行, 避免菜单缓存导致下载后不刷新)
	entry({"admin", "services", name}, call("action_index"), _("Subscribe"), 90).dependent = true
	entry({"admin", "services",name.."_status"}, call("Run_status")).leaf = true
	entry({"admin", "services", name, "download_exec"}, call("action_download")).leaf = true
	-- 注册菜单 --
	entry({"admin", "services", name, "settings_cbi"}, cbi(name.."/settings")).leaf = true
	entry({"admin", "services", name, "settings"}, call("action_index", "settings"), _("Settings"), 10).leaf = true
end

-- 二进制文件名与下载地址
local bin_file = name
local cn_url = string.format("https://cnb.cool/3wlh/Build-File/-/releases/download/GitHub-Actions_%s/%s-%%s",bin_file ,bin_file)
local default_url = string.format("https://github.com/3wlh/Build-Source/releases/download/GitHub-Actions_%s/%s-%%s",bin_file ,bin_file)

-- 主入口: 实时检查二进制, 存在则跳转设置页, 不存在则显示下载页面
function action_index(index)
	-- 取 URL 最后一段 "parse" / "logs"
	local index_name = luci.dispatcher.context.path[#luci.dispatcher.context.path]
	if api.installed(bin_file) then
		-- if index_name == "settings" then
		if index_name:match("settings") or index == nil then
			luci.http.redirect(luci.dispatcher.build_url("admin", "services", name, "settings_cbi"))
			return
		end	
		luci.template.render(name.."/" .. index_name, {
            Name = name,
        })
	else
		local info = api.arch_info(bin_file, api.Get_Url(cn_url, default_url))
		luci.template.render(name.."/download", {
			Name = name,
			arch = info.arch,
			pkg_arch = info.pkg_arch,
			bin_name = info.bin_name,
			bin_dir = info.bin_path,
			bin_url = info.bin_url
		})
	end
end

-- 启动下载
function action_download()
	local url  = luci.http.formvalue("url")
	local path = luci.http.formvalue("path")
	--local info = api.arch_info(bin_file, file_url)
	local total = tonumber(luci.http.formvalue("total"))
	luci.http.prepare_content("application/json")
	luci.http.write_json(api.download(path, url, total))
end

function Run_status()
	luci.http.prepare_content("application/json")
	local uci  = require "luci.model.uci".cursor()
	local port = tonumber(uci:get(name, "config", "port"))
	local token = uci:get(name, "config", "token")
	local cmd = string.format("pgrep %s* >/dev/null", name)
	local status = {
		running = (luci.sys.call(cmd) == 0),
		port = (port or 8066),
		token = (token or "")
	}
	luci.http.write_json(status)
end