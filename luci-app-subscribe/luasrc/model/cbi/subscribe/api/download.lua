module(..., package.seeall)
local fs  = require "nixio.fs"
local sys = require "luci.sys"

local install_dir = "/usr/sbin"

-- 检查文件是否为有效 ELF 二进制 (前4字节 \x7fELF)
local function is_elf(path)
	local f = io.open(path, "rb")
	if not f then return false end
	local magic = f:read(4)
	f:close()
	-- Lua 5.1 不支持 \x7f 转义, 用十进制 \127 (0x7f)
	return magic == "\127ELF"
end

-- 本地文件大小 (字节), 不存在返回 0
local function file_size(path)
	local s = fs.stat(path)
	return s and tonumber(s.size) or 0
end

-- 检测可用 HTTP 客户端 (缓存; 优先 curl: 重定向/HEAD 更可靠, BusyBox wget 功能受限)
local _client
local function http_client()
	if _client == nil then
		local p = sys.exec("command -v curl 2>/dev/null || command -v wget 2>/dev/null") or ""
		_client = p:find("curl") and "curl" or p:find("wget") and "wget" or ""
	end
	return _client
end

-- 远程文件总大小 (字节): 用已检测客户端取 Content-Length 末次 (重定向链中 200 的)
local function fetch_total(bin_url)
	local c = http_client()
	local out = ""
	if c == "curl" then
		out = sys.exec(string.format(
			"curl -fsIL --connect-timeout 5 --max-time 10 '%s' 2>/dev/null | grep -i 'content-length' | tail -1", bin_url)) or ""
	elseif c == "wget" then
		out = sys.exec(string.format(
			"wget --spider -S -t 1 -T 8 '%s' 2>&1 | grep -i 'content-length' | tail -1", bin_url)) or ""
	end
	return tonumber(out:match(":%s*(%d+)")) or 0
end

-- 下载进程是否存活 (pgrep -f 匹配已检测客户端 + tmp路径 + url)
-- pgrep -f 读 /proc/PID/cmdline 全量命令行, 不受 ps 无终端截断影响
-- 自匹配规避: 字符类 w[g]et / c[u]rl 使字面串不含 'wget'/'curl', 不命中 pgrep 自身
local function dl_running(file, url)
	local c = http_client()
	if c == "curl" then
		return sys.call(string.format("pgrep -f 'c[u]rl.*%s.*%s' >/dev/null 2>&1", file, url)) == 0
	elseif c == "wget" then
		return sys.call(string.format("pgrep -f 'w[g]et.*%s.*%s' >/dev/null 2>&1", file, url)) == 0
	end
	return false
end

-- 计算设备架构信息, 拼装下载URL
function arch_info(bin_file, file_url)
	local arch = sys.exec("uname -m 2>/dev/null") or ""
	arch = arch:gsub("%s+", "")
	local arch_map = { aarch64 = "arm64", x86_64 = "amd64" }
	local pkg_arch = arch_map[arch] or arch
	local bin_url = string.format(file_url, pkg_arch)
	return {
		arch = arch,
		pkg_arch = pkg_arch,
		bin_name = bin_url:match("([^/]+)$"),
		bin_path = install_dir .. "/" .. bin_file,
		bin_url = bin_url,
	}
end

-- 选择下载地址
function Get_Url(cn_url, default_url)
	local country = Get_Position()
	if country == "CN" then
		return cn_url
	end
	return default_url
end

-- 获取网络地址
function Get_Position()
    local c = http_client()
    if c == "" then
        return nil
    end
    local services = {
        -- 优先：HTTP，兼容性最好
        -- 腾讯：[https://i.news.qq.com;https://r.inews.qq.com/api/ip2city]
        {url = "https://i.news.qq.com/api/ip2city" , pattern = '"country":"([^"]+)"'},
        {url = "https://api.live.bilibili.com/xlive/web-room/v1/index/getIpInfo" , pattern = '"country":"([^"]+)"'},
        {url = "https://g3.letv.com/r?format=1" , pattern = '"geo"%s*:%s*"([^.]+)'},
        {url = "https://get.geojs.io/v1/ip/country" , pattern = "^(%u%u)"},
        {url = "https://get.geojs.io/" , pattern = "Country:.-%((%u%u)%)"},
		{url = "https://1.1.1.1/cdn-cgi/trace" , pattern = "loc=(%u%u)"},	
    }
    for _, svc in ipairs(services) do
		local output, country
        if c == "curl" then
			output = sys.exec(string.format("curl -s -m 2 '%s' 2>/dev/null", svc.url))
		elseif c == "wget" then
			output = sys.exec(string.format("wget -qO- -T 2 --no-check-certificate '%s' 2>/dev/null", svc.url)) 
		end
        if output and output ~= "" then
            country = output:match(svc.pattern)
            if country then
				if country == "中国" then
					country = "CN"
				elseif #country ~= 2 then
					country = nil
				end
				if country then 
					return country:upper() 
				end
			end
        end
    end
    return nil
end

-- 二进制是否已安装且有效
function installed(bin_file)
	return is_elf(install_dir .. "/" .. bin_file)
end


-- 安全校验 
-- 路径白名单: 必须是 install_dir 下的纯文件名 (无 .. / 无子目录 / 无特殊字符)
local function safe_path(p)
	return type(p) == "string"
	    and p:match("^" .. install_dir .. "/[%w%-%._]+$") ~= nil
end

-- URL 白名单: http(s) 协议 + 安全字符集 (不含引号/空格/分号/&/|/$/反引号等)
local function safe_url(u)
	return type(u) == "string"
	    and u:match("^https?://[%w%-%._~:/%?%=%&%%%+%#]+$") ~= nil
end

-- 纵深防御: 单引号转义 (白名单下理论上到不了这里, 双保险)
local function sh_quote(s)
	return (s:gsub("'", "'\\''"))
end

-- 启动下载(若无进程) + 返回当前状态 (单接口, 前端轮询同一URL)
function download(bin_path, bin_url, client_total)
	-- 文件已存在且有效 → 成功
	-- 下载先写 .tmp 完成后才 mv 到 bin_path, 故 bin_path 存在即代表下载完整, 不会被 partial 文件误判
	if is_elf(bin_path) then
		return { success = true }
	end
	-- ★ 入口校验: 不过白名单立即拒绝, 不执行任何命令
	if not safe_path(bin_path) then
		return { success = false, downloading = false, error = "invalid path" }
	end
	if not safe_url(bin_url) then
		return { success = false, downloading = false, error = "invalid url" }
	end
	-- 检测 HTTP 客户端, 无则停止 (前端见 downloading=false 停轮询)
	local c = http_client()
	if c == "" then
		return { success = false, downloading = false, percent = 0, total = 0 }
	end
	-- 文件不存在: 无下载进程才启动 (前端每 2s 轮询; 首次启动后后续轮询 dl_running=true 跳过, 防重复起进程)
	local tmp = bin_path .. ".tmp"
	if not dl_running(tmp, bin_url) then
		os.remove(bin_path)
		local qpath, qurl, qtmp = sh_quote(bin_path), sh_quote(bin_url), sh_quote(tmp)
		-- 下到 .tmp, 成功后 mv 到 bin_path (原子替换), 避免 partial 文件前4字节 ELF magic 触发 is_elf 误判完成
		-- 用已检测客户端构建命令 (curl 优先; 仅一个客户端, 无需 || 回退链)
		local cmd
		if c == "curl" then
			cmd = string.format(
				"(curl -fsL --connect-timeout 30 -o '%s' '%s' && mv -f '%s' '%s' && chmod 755 '%s' || rm -f '%s') >/dev/null 2>&1 </dev/null &",
				qtmp, qurl, qtmp, qpath, qpath, qtmp)
		else  -- wget
			cmd = string.format(
				"(wget -O '%s' '%s' && mv -f '%s' '%s' && chmod 755 '%s' || rm -f '%s') >/dev/null 2>&1 </dev/null &",
				qtmp, qurl, qtmp, qpath, qpath, qtmp)
		end
		sys.call(cmd)
	end
	-- 计算下载进度: tmp 已下载字节 / 远程总大小
	-- client_total 有效则直接用 (前端回传, 跳过 HEAD); 否则首次拉取
	local total = (client_total and client_total > 0) and client_total or fetch_total(bin_url)
	local cur = file_size(tmp)
	local pct = 0
	if total > 0 then
		pct = math.floor(cur * 100 / total)
		if pct > 99 then pct = 99 end  -- 未 mv 到 bin_path 前封顶 99, 与 success 区分
	end
	-- 下载中 (刚启动 或 上一次轮询已在跑); total 回传前端缓存
	return { success = false, downloading = true, percent = pct, total = total }
end
