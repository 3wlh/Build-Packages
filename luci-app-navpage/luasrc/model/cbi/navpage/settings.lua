local name = debug.getinfo(1, "S").source:match("/([^/]+)/[^/]+$")
local uci = require "luci.model.uci".cursor()

-- 翻译函数
local function _(s)
    return translate(s)
end

-- 初始化配置（确保模板有数据可用）
local function init_config()
    if not uci:get(name, "config") then
        uci:set(name, "config", "main")
        uci:reorder(name, "config", 0)
    end
    -- 基础配置默认值
    uci:set(name, "config", "enabled", uci:get(name, "config", "enabled") or 0)
    uci:set(name, "config", "port", uci:get(name, "config", "port") or "8080")
    uci:set(name, "config", "user", uci:get(name, "config", "user") or "")
    uci:set(name, "config", "password", uci:get(name, "config", "password") or "")
    uci:set(name, "config", "path_data", uci:get(name, "config", "path_data") or "/etc/"..name)
    uci:set(name, "config", "url", uci:get(name, "config", "url") or "")
    return
end

-- 初始化配置
init_config()

local m, s, o
m = Map(name, _("Configuration"), 
    _("A lightweight navigation page written in Go.") .. "<br/>" ..    
    _("Official reference") .. ": <a href='https://github.com/3wlh/NavPage' target='_blank'>NavPage</a>")

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
o.default = "8080"
o.rmempty = false
o.description = _("Web Service Port")

-- 账号配置
o = s:option(Value, "user", _("User"))
o.rmempty = true
o.datatype = "string"
o.description = _("Please enter your username above")

-- 密码配置
o = s:option(Value, "password", _("Password"))
o.password = true
o.rmempty = true
o.description = _("Please enter your password above")   

-- 数据目录配置
o = s:option(Value, "path_data", _("Data Catalog"))
o.default = "/etc/"..name
o.rmempty = true
o.datatype = "string"
o.description = _("Please enter your data catalog path above")

-- 数据目录配置
o = s:option(Value, "url", _("JSON Url"))
o.placeholder = "http(s)://example.com/navpage-config.json"
o.rmempty = true
o.datatype = "string"
o.description = _("Please enter your remote import JSON address above")

-- 渲染按钮
local cfg_port = string.format("%q", uci:get(name, "config", "port") or "8080")
o = s:option(DummyValue, "_webui", _("WebUI"))
o.rawhtml = true
o.value = '<button class="btn cbi-button cbi-button-action" onclick="openWebUI()">'.._("Open Web Page")..'</button>'
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