local name = debug.getinfo(1, "S").source:match("/([^/]+)/[^/]+$")
local uci = require "luci.model.uci".cursor()
local fs = require "nixio.fs"

-- 翻译函数
local function _(s)
    return translate(s)
end

-- 生成32位Token
local function generate_token()
    math.randomseed(os.time() + os.clock() * 1000000)
    local chars = "0123456789abcdefghijklmnopqrstuvwxyz"
    local result = ""
    local charsLen = #chars
    -- 循环生成32个随机字符
    for i = 1, 32 do
        -- 随机取字符集中的一个字符
        local randomIdx = math.random(1, charsLen)
        result = result .. string.sub(chars, randomIdx, randomIdx)
    end
    return result
end

-- 生成解密密钥（Key）的函数（保留原有逻辑，无错误）
local function generate_key()
    -- 获取eth0 MAC（优先ip命令）
    local cmd="ip -o link show eth0 2>/dev/null | grep -Eo 'permaddr ([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | awk '{print $NF}'"
    local mac = luci.sys.exec(cmd):gsub("%s+", "")
    -- 备用方法
    if not mac or mac == "" then
        mac = luci.sys.exec("cat /sys/class/net/eth0/address 2>/dev/null"):gsub("%s+", "")
    end
    -- local mac = luci.util.exec("ethtool -P eth0 | grep -o '[0-9a-f:]\{17\}' 2>/dev/null")
    local key = ""
    if mac and mac ~= "" then
        key = luci.sys.exec(string.format("echo -n '%s' | md5sum | awk '{print $1}' | cut -c9-24", mac)):gsub("%s+", "")
    end
    return mac, key
end

local device_mac, decrypt_key = generate_key()

-- 初始化配置（确保模板有数据可用）
local function init_config()
    if not uci:get(name, "config") then
        uci:set(name, "config", "main")
        uci:reorder(name, "config", 0)
    end
    -- 基础配置默认值
    uci:set(name, "config", "enabled", uci:get(name, "config", "enabled") or 0)
    uci:set(name, "config", "port", uci:get(name, "config", "port") or "5063")
    uci:set(name, "config", "netlink", uci:get(name, "config", "netlink") or 1)
    uci:set(name, "config", "path_config", uci:get(name, "config", "path_config") or "/etc/"..name)
    uci:set(name, "config", "pwd_config", uci:get(name, "config", "pwd_config") or decrypt_key)
    uci:set(name, "config", "online_config", uci:get(name, "config", "online_config") or "")
    uci:set(name, "config", "token", uci:get(name, "config", "token") or generate_token())
    return
end

-- 初始化配置
init_config()

local m, s, o
m = Map(name, _("Configuration"), 
    _("A lightweight DDNS automatic update tool that supports multiple DNS service providers.") .. "<br/>" ..    
    _("Official reference") .. ": <a href='https://github.com/3wlh/' target='_blank'>MultiDDNS</a>" ..
    (device_mac ~= "" and "<br><b>MAC: </b> <span style='color:#3498db;'>" .. device_mac .. "</span>" or ""))

m.apply_on_parse = true -- 解析阶段立即写入配置文件
m.on_after_commit = function(self)
    -- os.execute("/etc/init.d/"..name.." restart &")
end

-- 调用独立状态模板
s = m:section(SimpleSection)
s.template = name.."/status"
s.Name = name

-- 全局配置区域
s = m:section(TypedSection, "main", _("Basic Settings"))
s.addremove = false
s.anonymous = true

-- 启用开关
s:option(Flag, "enabled", _("Enable")).rmempty = false

-- 端口配置
o = s:option(Value, "port", _("Port"))
o.datatype = "port"
o.default = "5063"
o.rmempty = false
o.description = _("Web Service Port")

-- 配置网卡监控
o = s:option(ListValue, "netlink", _("Netlink"))
o:value("1", _("Enable"))
o:value("0", _("Disabled"))
o.default = "1"
o.rmempty = false
o.description = _('Whether to enable network card monitoring');

-- 配置文件路径
o = s:option(Value, "path_config", _("Config Path"))
o.default = "/etc/"..name
o.rmempty = true
o.datatype = "string"
o.description = _('Configuration File Storage Path');

-- 解密密钥
o = s:option(Value, "pwd_config", _("Decrypt KEY"))
o.default = decrypt_key
o.password = true
o.rmempty = true
o.description = _('Decryption Key[Auto MAC Generate]');

-- 在线配置URL
o = s:option(Value, "online_config", _("Online Config URL"))
o.placeholder = "http[s]://"
o.rmempty = true
o.datatype = "string"
o.description = _('URL for online configuration pull');

-- 下载配置到本地
local json = fs.readfile("/etc/"..name.."/config.json") or "{}"
local data  = nixio.bin.b64encode(json)
o = s:option(DummyValue, "_download", _("Download Config"))
o.rawhtml = true
o.value = '<a class="btn cbi-button cbi-button-action" '
    .. 'href="data:application/json;base64,' .. data .. '" '
    .. 'download="config.json">' .. _("Download") .. '</a>'
o.description = _('Download the configuration file to the local');

-- 渲染表单
return m