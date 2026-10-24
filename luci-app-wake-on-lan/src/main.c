#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <ctype.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <netdb.h>
#include "index_html.h"

#define PORT 8080
#define DEFAULT_TOKEN ""  // 默认空token，表示无需验证

// 全局变量：token和端口
static char global_token[256] = DEFAULT_TOKEN;
static int global_port = PORT;

// 解析MAC地址
int parse_mac_address(const char* mac_str, unsigned char* mac) {
    unsigned int values[6];
    int count = sscanf(mac_str, "%x:%x:%x:%x:%x:%x",
                       &values[0], &values[1], &values[2],
                       &values[3], &values[4], &values[5]);
    
    if (count != 6) {
        return -1;
    }
    
    for (int i = 0; i < 6; i++) {
        mac[i] = (unsigned char)values[i];
    }
    
    return 0;
}

// 获取本地IP和网段信息
void get_local_network(char* subnet_broadcast) {
    // 尝试通过DNS解析获取本机IP
    char hostname[256];
    gethostname(hostname, sizeof(hostname));
    
    struct hostent* host = gethostbyname(hostname);
    if (host && host->h_addr_list[0]) {
        struct in_addr addr;
        memcpy(&addr, host->h_addr_list[0], sizeof(struct in_addr));
        
        // 获取IP地址字符串
        //char* ip_str = inet_ntoa(addr);
        //fprintf(stderr, "本机 IP: %s\n", ip_str);
        
        // 构建子网广播地址（假设使用24位子网掩码）
        // 例如：192.168.1.1 -> 192.168.1.255
        unsigned int ip = addr.s_addr;
        unsigned int broadcast_addr = (ip & 0x00FFFFFF) | 0xFF000000;  // 最后一个字节改为255
        
        struct in_addr broadcast_ip;
        broadcast_ip.s_addr = broadcast_addr;
        strcpy(subnet_broadcast, inet_ntoa(broadcast_ip));
        
        fprintf(stderr, "子网广播: %s\n", subnet_broadcast);
    } else {
        // 如果无法获取，使用默认值
        strcpy(subnet_broadcast, "255.255.255.255");
        fprintf(stderr, "无法检测子网，使用全网广播\n");
    }
}

// 发送Wake-on-LAN魔术包（智能发送）
int send_wol_packet(const char* mac_str) {
    unsigned char mac[6];
    
    // 解析MAC地址
    if (parse_mac_address(mac_str, mac) != 0) {
        fprintf(stderr, "错误：无效的MAC地址格式: %s\n", mac_str);
        return -1;
    }
    
    fprintf(stderr, "MAC地址: %02X:%02X:%02X:%02X:%02X:%02X\n", 
            mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    
    // 构建标准的魔术包（102字节）
    unsigned char packet[102];
    for (int i = 0; i < 6; i++) packet[i] = 0xFF;
    for (int i = 0; i < 16; i++) memcpy(&packet[6 + i * 6], mac, 6);
    
    // 创建UDP socket
    int sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (sock < 0) {
        fprintf(stderr, "错误：创建socket失败\n");
        return -1;
    }
    
    // 允许广播
    int broadcast = 1;
    setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast));
    
    // 自动检测网段
    char subnet_broadcast[64];
    get_local_network(subnet_broadcast);
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    
    int success_count = 0;

    // 1. 子网广播地址（端口7）
    addr.sin_port = htons(7);
    addr.sin_addr.s_addr = inet_addr(subnet_broadcast);
    if (sendto(sock, packet, sizeof(packet), 0, (struct sockaddr*)&addr, sizeof(addr)) > 0) {
        fprintf(stderr, "[1] 发送到 %s:7\n", subnet_broadcast);
        success_count++;
    }
    
    // 2. 子网广播地址（端口9）
    addr.sin_port = htons(9);
    addr.sin_addr.s_addr = inet_addr(subnet_broadcast);
    if (sendto(sock, packet, sizeof(packet), 0, (struct sockaddr*)&addr, sizeof(addr)) > 0) {
        fprintf(stderr, "[2] 发送到 %s:9\n", subnet_broadcast);
        success_count++;
    }

    // 3. 全网广播地址（端口7）
    addr.sin_port = htons(7);
    addr.sin_addr.s_addr = inet_addr("255.255.255.255");
    if (sendto(sock, packet, sizeof(packet), 0, (struct sockaddr*)&addr, sizeof(addr)) > 0) {
        fprintf(stderr, "[3] 发送到 255.255.255.255:7\n");
        success_count++;
    }

    // 4. 全网广播地址（端口9）
    addr.sin_port = htons(9);
    addr.sin_addr.s_addr = inet_addr("255.255.255.255");
    if (sendto(sock, packet, sizeof(packet), 0, (struct sockaddr*)&addr, sizeof(addr)) > 0) {
        fprintf(stderr, "[4] 发送到 255.255.255.255:9\n");
        success_count++;
    }
    
    close(sock);
    
    fprintf(stderr, "总共发送: %d 个包\n", success_count);
    return (success_count > 0) ? 0 : -1;
}

// URL解码
void url_decode(char* dst, const char* src) {
    char a, b;
    while (*src) {
        if (*src == '%' &&
            (a = src[1]) && (b = src[2]) &&
            isxdigit(a) && isxdigit(b)) {
            if (a >= 'a') a -= 'a' - 'A';
            if (a >= 'A') a -= ('A' - 10);
            else a -= '0';
            if (b >= 'a') b -= 'a' - 'A';
            if (b >= 'A') b -= ('A' - 10);
            else b -= '0';
            *dst++ = 16 * a + b;
            src += 3;
        } else if (*src == '+') {
            *dst++ = ' ';
            src++;
        } else {
            *dst++ = *src++;
        }
    }
    *dst = '\0';
}

// 从查询字符串中获取参数值
int get_query_param(const char* query, const char* param, char* value, int max_len) {
    if (!query || !param || !value) return -1;
    
    char search[256];
    snprintf(search, sizeof(search), "%s=", param);
    
    const char* pos = strstr(query, search);
    if (!pos) return -1;
    
    pos += strlen(search);
    
    const char* end = strchr(pos, '&');
    int len = end ? (end - pos) : strlen(pos);
    
    if (len >= max_len) return -1;
    
    char encoded[512];
    strncpy(encoded, pos, len);
    encoded[len] = '\0';
    
    url_decode(value, encoded);
    
    return 0;
}

// 发送HTTP响应
void send_http_response(int client_fd, int status_code, const char* content_type, const char* body) {
    int body_len = strlen(body);
    
    // 发送HTTP头
    char header[256];
    snprintf(header, sizeof(header),
             "HTTP/1.1 %d OK\r\n"
             "Content-Type: %s\r\n"
             "Content-Length: %d\r\n"
             "Connection: close\r\n"
             "\r\n",
             status_code, content_type, body_len);
    
    send(client_fd, header, strlen(header), 0);
    
    // 发送HTTP体（分块发送避免缓冲区限制）
    int sent = 0;
    while (sent < body_len) {
        int chunk_size = 1024;  // 每次发送1KB
        if (sent + chunk_size > body_len) {
            chunk_size = body_len - sent;
        }
        int result = send(client_fd, body + sent, chunk_size, 0);
        if (result < 0) break;
        sent += result;
    }
}

// 处理主页请求
void handle_root(int client_fd, const char* query) {
    (void)query; // 未使用的参数
    
    // 根据令牌状态动态修改页面
    if (strlen(global_token) == 0) {
        // 无需令牌验证，修改页面中的配置标志
        char* modified_page = malloc(strlen(MAIN_PAGE) + 1);
        strcpy(modified_page, MAIN_PAGE);
        
        // 将 "let needToken = true;" 替换为 "let needToken = false;"
        char* pos = strstr(modified_page, "let needToken = true;");
        if (pos) {
            memcpy(pos, "let needToken = false;", 22);
        }
        
        send_http_response(client_fd, 200, "text/html; charset=utf-8", modified_page);
        free(modified_page);
    } else {
        // 需要令牌验证，直接返回原始页面
        send_http_response(client_fd, 200, "text/html; charset=utf-8", MAIN_PAGE);
    }
}

// 处理唤醒请求
void handle_wake(int client_fd, const char* query) {
    char mac[64] = {0};
    char token[256] = {0};
    char json_response[512];
    
    // 获取mac参数
    if (get_query_param(query, "mac", mac, sizeof(mac)) != 0) {
        snprintf(json_response, sizeof(json_response), 
                 "{\"status\":\"error\",\"message\":\"缺少MAC地址参数\"}");
        send_http_response(client_fd, 400, "application/json; charset=utf-8", json_response);
        return;
    }
    
    // 如果需要令牌验证，获取token参数
    if (strlen(global_token) > 0) {
        if (get_query_param(query, "token", token, sizeof(token)) != 0) {
            snprintf(json_response, sizeof(json_response), 
                     "{\"status\":\"error\",\"message\":\"缺少令牌参数\"}");
            send_http_response(client_fd, 400, "application/json; charset=utf-8", json_response);
            return;
        }
        
        // 验证token
        if (strcmp(token, global_token) != 0) {
            snprintf(json_response, sizeof(json_response), 
                     "{\"status\":\"error\",\"message\":\"令牌无效\"}");
            send_http_response(client_fd, 403, "application/json; charset=utf-8", json_response);
            return;
        }
    }
    
    // 发送WOL包
    int result = send_wol_packet(mac);
    
    if (result == 0) {
        snprintf(json_response, sizeof(json_response), 
                 "{\"status\":\"success\",\"message\":\"唤醒信号已发送\",\"mac\":\"%s\"}", mac);
        send_http_response(client_fd, 200, "application/json; charset=utf-8", json_response);
    } else {
        snprintf(json_response, sizeof(json_response), 
                 "{\"status\":\"error\",\"message\":\"发送唤醒信号失败\",\"mac\":\"%s\"}", mac);
        send_http_response(client_fd, 500, "application/json; charset=utf-8", json_response);
    }
}

// 处理HTTP请求
void handle_client(int client_fd) {
    char buffer[2048] = {0};  // 接收HTTP请求的缓冲区
    int bytes_received = recv(client_fd, buffer, sizeof(buffer) - 1, 0);
    
    if (bytes_received < 0) {
        close(client_fd);
        return;
    }
    
    // 解析HTTP请求
    char method[16], path[256];
    sscanf(buffer, "%s %s", method, path);
    
    // 提取查询字符串
    char* query = strchr(path, '?');
    if (query) {
        *query = '\0';  // 分割路径和查询
        query++;        // 指向查询字符串
    }
    
    // 处理请求
    if (strcmp(path, "/") == 0 || strcmp(path, "/index.html") == 0) {
        handle_root(client_fd, query);
    } else if (strcmp(path, "/wake") == 0) {
        handle_wake(client_fd, query);
    } else {
        // 404
        char error_html[512];
        snprintf(error_html, sizeof(error_html), 
                 "<html><body><h1>Error Occurred</h1><p id=\"errorMsg\">Page not found</p></body></html>");
        send_http_response(client_fd, 404, "text/html", error_html);
    }
    
    close(client_fd);
}

int main(int argc, char* argv[]) {
    // 解析命令行参数
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-p") == 0 && i + 1 < argc) {
            global_port = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-t") == 0 && i + 1 < argc) {
            strncpy(global_token, argv[++i], sizeof(global_token) - 1);
        }
    }
    
    printf("Wake-on-LAN 服务器运行在端口 %d\n", global_port);
    printf("访问地址: http://0.0.0.0:%d/\n", global_port);
    if (strlen(global_token) > 0) {
        printf("访问令牌: %s (需要验证)\n", global_token);
    } else {
        printf("访问令牌: 无 (无需验证)\n");
    }
    
    // 创建socket
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        fprintf(stderr, "创建socket失败\n");
        return 1;
    }
    
    // 设置socket选项
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    // 绑定地址
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(global_port);
    
    if (bind(server_fd, (struct sockaddr*)&address, sizeof(address)) < 0) {
        fprintf(stderr, "绑定端口 %d 失败\n", global_port);
        close(server_fd);
        return 1;
    }
    
    // 监听
    if (listen(server_fd, 10) < 0) {
        fprintf(stderr, "监听失败\n");
        close(server_fd);
        return 1;
    }
    
    printf("服务器就绪，等待连接...\n");
    
    // 接受连接循环
    while (1) {
        struct sockaddr_in client_addr;
        int client_len = sizeof(client_addr);
        int client_fd = accept(server_fd, (struct sockaddr*)&client_addr, (socklen_t*)&client_len);
        
        if (client_fd < 0) {
            fprintf(stderr, "接受连接失败\n");
            continue;
        }
        
        handle_client(client_fd);
    }
    
    close(server_fd);
    return 0;
}