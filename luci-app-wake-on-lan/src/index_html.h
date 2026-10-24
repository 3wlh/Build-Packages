#ifndef PAGES_H
#define PAGES_H

// 唤醒页面 HTML
static const char* MAIN_PAGE = R"html(
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>网络唤醒</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Microsoft YaHei', sans-serif;
            background: linear-gradient(135deg, #e6e9ff 0%, #f0e6ff 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 {
            color: #333;
            margin-bottom: 30px;
            font-size: 2.2em;
            text-align: center;
        }
        .form-group {
            margin-bottom: 25px;
        }
        label {
            display: block;
            color: #333;
            font-weight: 600;
            margin-bottom: 8px;
        }
        input {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 1em;
            font-family: 'Courier New', monospace;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%;
            padding: 15px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 1.1em;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
        }
        button:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }
        .footer {
            text-align: center;
            margin-top: 25px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            color: #999;
            font-size: 0.85em;
        }
        .toast {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 20px 30px;
            border-radius: 10px;
            color: white;
            font-weight: 600;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
            z-index: 9999;
            display: none;
            animation: slideIn 0.3s ease;
        }
        .toast.success {
            background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
        }
        .toast.error {
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
        }
        @keyframes slideIn {
            from { transform: translateX(100%); opacity: 0; }
            to { transform: translateX(0); opacity: 1; }
        }
    </style>
</head>
<body>
    <div class="toast" id="toast"></div>
    
    <!-- TOKEN_CONFIG: 由服务器动态注入 -->
    
    <div class="container">
        <h1>网络唤醒</h1>
        
        <form id="wakeForm">
            <div class="form-group">
                <label for="mac">MAC 地址</label>
                <input type="text" id="mac" placeholder="例：XX:XX:XX:XX:XX:XX" required>
            </div>
            
            <div class="form-group" id="tokenGroup">
                <label for="token">唤醒令牌</label>
                <input type="text" id="token" placeholder="请输入唤醒令牌">
            </div>
            
            <button type="submit" id="wakeBtn">发送唤醒信号</button>
        </form>
        
        <div class="footer">
            <p>Wake-on-LAN 网络唤醒服务</p>
            <p>Powered by 3wlh ©2026</p>
        </div>
    </div>
    
    <script>
        // 配置标志（服务器会注入：NEED_TOKEN 或 NO_TOKEN）
        let needToken = true;  // 默认需要令牌
        
        // 显示通知
        function showToast(message, type) {
            const toast = document.getElementById('toast');
            toast.textContent = message;
            toast.className = 'toast ' + type;
            toast.style.display = 'block';
            
            setTimeout(() => {
                toast.style.display = 'none';
            }, 3000);
        }
        
        // 获取URL参数
        function getUrlParam(name) {
            const params = new URLSearchParams(window.location.search);
            return params.get(name) || '';
        }
        
        // 页面加载时自动填充URL参数并调整界面
        window.onload = function() {
            const mac = getUrlParam('mac');
            const token = getUrlParam('token');
            
            if (mac) document.getElementById('mac').value = mac;
            if (token) document.getElementById('token').value = token;
            
            // 根据配置隐藏令牌输入框
            if (!needToken) {
                document.getElementById('tokenGroup').style.display = 'none';
            }
        };
        
        // 发送唤醒请求
        document.getElementById('wakeForm').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const mac = document.getElementById('mac').value.trim();
            const token = document.getElementById('token').value.trim();
            const btn = document.getElementById('wakeBtn');
            
            if (!mac) {
                showToast('请填写MAC地址', 'error');
                return;
            }
            
            // 如果需要令牌，验证是否填写
            if (needToken && !token) {
                showToast('请填写唤醒令牌', 'error');
                return;
            }
            
            btn.disabled = true;
            btn.textContent = '正在发送...';
            
            fetch('/wake?mac=' + encodeURIComponent(mac) + '&token=' + encodeURIComponent(token))
                .then(response => response.json())
                .then(data => {
                    if (data.status === 'success') {
                        showToast('✓ 唤醒信号已发送到 ' + mac, 'success');
                    } else {
                        showToast('✗ ' + data.message, 'error');
                    }
                })
                .catch(err => {
                    showToast('✗ 网络错误: ' + err.message, 'error');
                })
                .finally(() => {
                    btn.disabled = false;
                    btn.textContent = '发送唤醒信号';
                });
        });
    </script>
</body>
</html>
)html";

#endif // PAGES_H