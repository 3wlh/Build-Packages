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

-- 初始化配置（确保模板有数据可用）
local function init_config()
    if not uci:get(name, "config") then
        uci:set(name, "config", "main")
        uci:reorder(name, "config", 0)
    end
    -- 基础配置默认值
    uci:set(name, "config", "enabled", uci:get(name, "config", "enabled") or 0)
    uci:set(name, "config", "port", uci:get(name, "config", "port") or "7864")
    uci:set(name, "config", "data_path", uci:get(name, "config", "path_config") or "/etc/"..name.."/data")
    uci:set(name, "config", "token", uci:get(name, "config", "token") or generate_token())
    return
end

-- 初始化配置
init_config()

local m, s, o
m = Map(name, _("Configuration"), 
    _("AI Work 助手 — AI 应用多账号管理一体化工具.") .. "<br/>" ..    
    _("Official reference") .. ": <a href='https://github.com/smart-open/TraeWorkAssistant' target='_blank'>TraeWorkAssistant</a>")

m.apply_on_parse = true -- 解析阶段立即写入配置文件
m.on_after_commit = function(self)
    -- os.execute("/etc/init.d/"..name.." restart &")
end

-- 调用独立状态模板
s = m:section(SimpleSection)
s.template = name.."/status"
s.Name = name

-- 全局配置区域
s = m:section(TypedSection, "main", _("基础设置"))
s.addremove = false
s.anonymous = true

-- 启用开关
s:option(Flag, "enabled", _("Enable")).rmempty = false

-- 端口配置
o = s:option(Value, "port", _("访问端口"))
o.datatype = "port"
o.default = "7864"
o.rmempty = false
o.description = _("访问网页端口")

-- 在线配置URL
o = s:option(Value, "token", _("访问密钥"))
o.placeholder = generate_token()
o.password = true
o.rmempty = true
o.description = _('访问网页登录密钥');

-- 配置文件路径
o = s:option(Value, "path_config", _("数据目录"))
o.default = "/etc/"..name.."/data"
o.rmempty = true
o.datatype = "string"
o.description = _('数据保存的目录');

-- 渲染表单
return m