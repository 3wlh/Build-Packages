-- luci-app-smbvfs
-- 为所有 Samba 共享统一添加 fruit (macOS 兼容) 配置:
-- xattr 走扩展流存储, macOS 客户端不再生成 ._ 边车文件

module("luci.controller.smbvfs", package.seeall)

local http = require "luci.http"
local sys  = require "luci.sys"
local fs   = require "nixio.fs"
local uci  = require "luci.model.uci".cursor()

local FRUIT_OPTS = {
	{ "vfs_objects",               "catia fruit streams_xattr" },
	{ "fruit_metadata",            "stream" },
	{ "fruit_model",               "MacSamba" },
	{ "fruit_posix_rename",        "yes" },
	{ "fruit_delete_emptyadfiles", "yes" },
}

function index()
	entry({ "admin", "services", "smbvfs" },
		template("smbvfs/main"), _("SMB VFS"), 90).dependent = false
	entry({ "admin", "services", "smbvfs", "status" },
		call("action_status")).leaf = true
	local apply = entry({ "admin", "services", "smbvfs", "apply" },
		call("action_apply"))
	apply.leaf = true
	apply.post = true
	local boot = entry({ "admin", "services", "smbvfs", "boot" },
		call("action_boot"))
	boot.leaf = true
	boot.post = true
end

local function executable(path)
	return fs.access(path, "x")
end

local function samba_service()
	if executable("/etc/init.d/samba4") then return "samba4" end
	if executable("/etc/init.d/samba")  then return "samba"  end
end

local function write_json(status, data)
	http.status(status, ({ [200] = "OK", [405] = "Method Not Allowed",
		[409] = "Conflict", [500] = "Internal Server Error" })[status] or "Unknown")
	http.prepare_content("application/json")
	http.write_json(data)
end

local function boot_enabled()
	return executable("/etc/init.d/smbvfs")
		and sys.call("ls /etc/rc.d/S??smbvfs >/dev/null 2>&1") == 0
end

local function daemon_running()
	return sys.exec("ubus call service list '{\"name\":\"smbvfs\"}' 2>/dev/null"):match('"smbvfs"') ~= nil
end

function action_status()
	local svc = samba_service()
	local shares = {}
	uci:foreach("samba4", "sambashare", function(s)
		shares[#shares + 1] = {
			name        = s[".name"],
			path        = s.path or "",
			vfs_objects = s.vfs_objects or "",
			fruit       = (s.vfs_objects == FRUIT_OPTS[1][2]) and 1 or 0,
		}
	end)
	write_json(200, {
		service  = svc or "",
		running  = (svc and sys.call("/etc/init.d/" .. svc .. " running >/dev/null 2>&1") == 0) and 1 or 0,
		enabled  = boot_enabled() and 1 or 0,
		daemon   = daemon_running() and 1 or 0,
		shares   = shares,
	})
end

function action_boot()
	if http.getenv("REQUEST_METHOD") ~= "POST" then
		write_json(405, { error = "POST required" })
		return
	end
	if not executable("/etc/init.d/smbvfs") then
		write_json(500, { error = "smbvfs init script is missing" })
		return
	end
	if http.formvalue("state") == "1" then
		sys.call("/etc/init.d/smbvfs enable >/dev/null 2>&1")
		sys.call("/etc/init.d/smbvfs start  >/dev/null 2>&1")
	else
		sys.call("/etc/init.d/smbvfs disable >/dev/null 2>&1")
		sys.call("/etc/init.d/smbvfs stop    >/dev/null 2>&1")
	end
	write_json(200, { enabled = boot_enabled() and 1 or 0 })
end

function action_apply()
	if http.getenv("REQUEST_METHOD") ~= "POST" then
		write_json(405, { error = "POST required" })
		return
	end

	local log = {}

	-- 先重启 unishare, 避免它之后重新生成 samba 配置时覆盖 fruit 选项
	if executable("/etc/init.d/unishare") then
		log[#log + 1] = "restarting unishare ..."
		sys.call("/etc/init.d/unishare restart >/dev/null 2>&1")
	end

	-- 遍历所有 sambashare 段 (按名字索引, 不依赖序号)
	local count = 0
	uci:foreach("samba4", "sambashare", function(s)
		log[#log + 1] = "configuring: " .. (s[".name"] or "?")
		for _, o in ipairs(FRUIT_OPTS) do
			uci:set("samba4", s[".name"], o[1], o[2])
		end
		count = count + 1
	end)

	if count == 0 then
		log[#log + 1] = "ERROR: 未找到任何 samba4 sambashare 配置段"
		write_json(409, { error = "No sambashare sections", log = table.concat(log, "\n") })
		return
	end

	uci:commit("samba4")
	log[#log + 1] = string.format("configured %d share(s), samba4 committed", count)

	-- 启用开机脚本, 防止重启后配置被 unishare 覆盖
	if executable("/etc/init.d/smbvfs") then
		sys.call("/etc/init.d/smbvfs enable >/dev/null 2>&1")
		log[#log + 1] = "smbvfs boot script enabled"
	end

	-- 重启 samba 服务 (兼容 samba4 / samba 两种命名)
	local svc = samba_service()
	if not svc then
		log[#log + 1] = "ERROR: 未找到 samba 服务, 相关服务列表:"
		log[#log + 1] = sys.exec("ls /etc/init.d/ | grep -iE 'samba|smb|uni' 2>/dev/null")
		write_json(500, { error = "Samba service not found", log = table.concat(log, "\n") })
		return
	end
	sys.call("/etc/init.d/" .. svc .. " restart >/dev/null 2>&1")
	log[#log + 1] = svc .. " restarted"

	-- 验证: 每个共享段都应出现 vfs objects = catia fruit streams_xattr
	log[#log + 1] = "---- verification ----"
	log[#log + 1] = sys.exec("grep -E '^\\[|vfs objects' /etc/samba/smb.conf 2>/dev/null")

	write_json(200, { ok = 1, shares = count, log = table.concat(log, "\n") })
end
