local name = debug.getinfo(1, "S").source:match("/([^/]+)/[^/]+$")
local uci = require "luci.model.uci".cursor()
local fs = require "nixio.fs"

-- 翻译函数
local function _(s)
    return translate(s)
end

-- 生成随机uuid
local function generateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- 初始化配置（确保模板有数据可用）
local function init_config()
    if not uci:get(name, "config") then
        uci:set(name, "config", "main")
        uci:reorder(name, "config", 0)
    end
    -- 基础配置默认值
    uci:set(name, "config", "enabled", uci:get(name, "config", "enabled") or 0)
    uci:set(name, "config", "port", uci:get(name, "config", "port") or "5063")
    uci:set(name, "config", "host", uci:get(name, "config", "host") or "")
    uci:set(name, "config", "uuid", uci:get(name, "config", "uuid") or "")
    uci:set(name, "config", "auth", uci:get(name, "config", "auth") or "")
    uci:set(name, "config", "subscribe", uci:get(name, "config", "subscribe") or "")
    return
end

-- 初始化配置
init_config()

local m, s, o
m = Map(name, _("Configuration"), 
    _("This is a software that automatically generates node subscriptions.") .. "<br/>" ..    
    _("Official reference") .. ": <a href='https://github.com/3wlh/' target='_blank'>Subscribe</a>")

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

-- 配置服务端口
o = s:option(Value, "port", _("Port"))
o.datatype = "port"
o.default = "8066"
o.rmempty = false
o.description = _("Service Port")

-- 配置域名
o = s:option(Value, "host", _("Host"))
o.rmempty = true
o.datatype = "string"
o.description = _('Configure the domain name of the subscription node');

-- 配置UUID
o = s:option(Value, "uuid", _("UUID"))
o.placeholder = generateUUID()
o.rmempty = true
o.datatype = "string"
o.description = _('Configure the UUID of the subscription node');

-- 配置UUID
o = s:option(Value, "auth", _("Auth"))
o.placeholder = "admin:password"
o.rmempty = true
o.datatype = "string"
o.description = _('Configure SOCKS Authentication');

-- 配置订阅
o = s:option(Value, "subscribe", _("Subscribe"))
o.placeholder = "vless=4333|vmess=4334|socks=4335"
o.rmempty = true
o.datatype = "string"
-- 配置订阅的节点
o.description = _('Configure the subscribed nodes');

-- 渲染表单
return m