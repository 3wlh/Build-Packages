local name="wake-on-lan"
local uci = require "luci.model.uci".cursor()

-- 翻译函数
local function _(s)
    return translate(s)
end

-- 初始化配置（确保模板有数据可用）
local function init_config()
    local section = uci:get(name, "config")
    if not section then
        section = uci:set(name, "config","main")
    end
    -- 基础配置默认值
    uci:set(name, "config", "port", uci:get(name, "config", "port") or '5056')
    uci:set(name, "config", "token", uci:get(name, "config", "token") or "")
    return
end

init_config()

-- 全中文配置
local m, s, o
m = Map(name,  _("Configuration"),_("Plug-in for Wake-on-LAN devices"))

m.apply_on_parse = true -- 解析阶段立即写入配置文件
m.on_after_commit = function(self)
    -- os.execute("/etc/init.d/"..name.." restart &")
end

-- 调用独立状态模板
s = m:section(SimpleSection)
s.template = name.."/status"
s.Name = name
 
s = m:section(TypedSection, "main", _("Basic Settings"))
s.anonymous = true
s.addremove = false

-- 启用开关
s:option(Flag, "enabled", _("Enable")).rmempty = false

-- 端口
o= s:option(Value,"port", _("Port"))
o.default = "5056"
o.datatype = "string"
o.rmempty = true
o.description = _("Web Service Port")

-- 令牌
o = s:option(Value, "token",  _("Token"))
o.datatype = "string"
o.password = true
o.rmempty = true
o.description = _("Token used for remote wake-up of devices")

return m