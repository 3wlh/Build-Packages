local name=debug.getinfo(1, "S").source:match("/([^/]+)/[^/]+$")
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

-- 初始化配置（确保模板有数据可用）
local function init_config()
    if not uci:get(name, "config") then
        uci:set(name, "config", "main")
        uci:reorder(name, "config", 0)
    end
    -- 基础配置默认值
    uci:set(name, "config", "enabled", uci:get(name, "config", "enabled") or 0)
    uci:set(name, "config", "port", uci:get(name, "config", "port") or "8887")
    uci:set(name, "config", "token", uci:get(name, "config", "token") or generate_token())
    return
end

-- 初始化配置
init_config()

local m, s, o
m = Map(name, _("Configuration"), 
    _("Photopea is online image editor.") .. "<br/>" ..
    _("Official website") .. ": <a href='www.Photopea.com' target='_blank'>Photopea</a>")

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
o.default = "8887"
o.rmempty = false
o.description = _("Access Service Port")

-- 解密密钥
o = s:option(Value, "token", _("Token"))
o.default = generate_token()
o.password = true
o.rmempty = true
o.description = _('Automatically generated 32-bit token');

-- 渲染按钮
local cfg_port = string.format("%q", uci:get(name, "config", "port") or "8887")
o = s:option(DummyValue, "_webui", _("WebUI"))
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