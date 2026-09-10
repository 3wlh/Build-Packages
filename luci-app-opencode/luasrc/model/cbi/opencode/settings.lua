local name = debug.getinfo(1, "S").source:match("/([^/]+)/[^/]+$")
local uci = require "luci.model.uci".cursor()
local fs = require "nixio.fs"

-- 翻译函数
local function _(s)
    return translate(s)
end

-- 生成8位Token
local function generate_token()
    math.randomseed(os.time() + os.clock() * 1000000)
    local chars = "0123456789abcdefghijklmnopqrstuvwxyz"
    local result = ""
    local charsLen = #chars
    -- 循环生成32个随机字符
    for i = 1, 8 do
        -- 随机取字符集中的一个字符
        local randomIdx = math.random(1, charsLen)
        result = result .. string.sub(chars, randomIdx, randomIdx)
    end
    return result
end

-- 初始化配置（确保模板有数据可用）
local function init_config()
    if not uci:get(name, "config") then
        uci:set(name, "config", "main")
        uci:reorder(name, "config", 0)
    end
    -- 基础配置默认值
    uci:set(name, "config", "enabled", uci:get(name, "config", "enabled") or 0)
    uci:set(name, "config", "port", uci:get(name, "config", "port") or "4096")
    uci:set(name, "config", "username", uci:get(name, "config", "username") or "opencode")
    uci:set(name, "config", "password", uci:get(name, "config", "password") or "")
    return
end

-- 初始化配置
init_config()
 
local m, s, o
m = Map(name, _("Configuration"), 
    _("OpenCode is an open-source AI coding agent. It offers multiple ways to use, including a terminal interface, a desktop app, and IDE extensions.")
    .."<br/>".._("Official reference")..": <a href='https://opencode.ai/docs' target='_blank'>OpenCode</a>")

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
-- s:option(Flag, "enabled", _("Enable")).rmempty = false
o = s:option(ListValue, "enabled", _("Service"))
o:value("1", _("Enable"))
o:value("0", _("Disabled"))
o.default = "0"
o.rmempty = false

-- 端口配置
o = s:option(Value, "port", _("Port"))
o.datatype = "port"
o.default = "4096"
o.rmempty = false
o.description = _("Web Service Port")

-- 配置文件路径
o = s:option(Value, "username", _("Username"))
o.rmempty = true
o.datatype = "string"
o.description = _('Please enter the username for accessing the software.');

-- 解密密钥
o = s:option(Value, "password", _("Password"))
o.password = true
o.rmempty = true
o.description = _('Please enter the password for accessing the software.');

-- 渲染按钮
local cfg_port = string.format("%q", uci:get(name, "config", "port") or "4096")
o = s:option(DummyValue, "_webui", "WebUI")
o.rawhtml = true
o.value = '<button class="btn cbi-button cbi-button-action" onclick="openWebUI()">'.._("Open Web app")..'</button>'
	.. '<script>'
	.. 'function openWebUI(){'
	.. 'var port=document.querySelector(\'input[id$=".port"]\');'
	.. 'var p=(port&&port.value)?port.value:'..cfg_port..';'
	.. 'var url=window.location.protocol+"//"+window.location.hostname+":"+p;'
	.. 'window.open(url,"_blank");'
	.. '}'
	.. '</script>'

-- 渲染表单
return m