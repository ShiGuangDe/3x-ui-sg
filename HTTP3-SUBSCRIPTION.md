# HTTP/3（UDP）备用订阅

当客户端到服务器的 TCP 连接受阻、UDP 仍可用时，支持 HTTP/3 直连下载的客户端可以通过此入口更新订阅。它不能保证任何网络下都可达，也不能让原本不支持 HTTP/3 订阅的客户端自动具备此能力。

## 客户端支持范围

本次核对日期：2026-10-28。以下是源码核对结果，具体安装版本仍需验证。

| 客户端 | 直接通过 UDP 拉订阅 |
| --- | --- |
| NekoBox for Android | 上游 `RawUpdater` 调用 `tryH3Direct()`；本地代理未连接时，会尝试 HTTP/3 直连。TCP 代理失效时，先断开代理，再更新事先保存的备用订阅。 |
| v2rayN | 当前上游订阅下载器未启用 HTTP/3。这个二维码不能强制它走 UDP。可以提前保存 Hysteria2 等 UDP 节点，连接后使用“通过代理更新订阅”，或另行修改客户端的下载器。 |
| Shadowrocket（小火箭） | 未完成实机验证，不能承诺 TCP 完全不可达时直接用 HTTP/3 更新订阅。可以预先保存支持的 UDP 备用节点，连接后通过代理更新订阅，具体行为需要在设备上确认。 |

参考：[NekoBox 订阅更新器](https://github.com/MatsuriDayo/NekoBoxForAndroid/blob/main/app/src/main/java/io/nekohasekai/sagernet/group/RawUpdater.kt)、[NekoBox HTTP/3 直连实现](https://github.com/MatsuriDayo/NekoBoxForAndroid/blob/main/libcore/http.go)、[v2rayN 订阅下载器](https://github.com/2dust/v2rayN/blob/master/v2rayN/ServiceLib/Services/DownloadService.cs)。最新版上游 [3x-ui 订阅服务](https://github.com/MHSanaei/3x-ui/blob/main/internal/sub/sub.go) 本次核对仍使用 TCP 监听；此分支复用原订阅路由，自行增加 HTTP/3 监听。

## 面板设置

进入 **面板设置 → 订阅设置 → HTTP/3（UDP）订阅服务**：

1. 打开 **启用订阅服务**。新功能默认关闭，独立于原 HTTP(S)/TCP 订阅开关。
2. 设置监听地址和 **UDP 端口**（默认 2097）。留空监听地址表示监听所有地址。
3. 配置域名和证书。HTTP/3 必须使用 TLS，域名或 IP 必须与客户端信任的证书匹配。不要为了方便关闭客户端证书校验。
4. 证书、私钥均留空时沿用原订阅服务的证书；否则必须同时提供两个文件路径。原订阅通过反向代理终止 TLS 时，也需为此 UDP 服务单独提供证书。
5. 公开链接前缀可留空，自动按域名、UDP 端口和原订阅路径生成。自行填写时须为 `https://域名[:端口]/路径/`，以 `/` 结尾，不带订阅 ID、账号、查询参数或片段。此配置不自动建立端口转发。
6. 保存设置并重启面板，在服务器防火墙及云安全组放行相应 UDP 端口。

不能与 Hysteria2、TUIC 等现有服务占用相同的监听地址和 UDP 端口；TCP 和 UDP 可以使用相同的端口号。域名如经过 CDN，必须确认 CDN 到此服务的链路支持所需的 UDP 转发；给 CDN 开启 HTTP/3 不代表它会把 HTTP/3 转发到源站 UDP 端口。

原订阅 ID、节点、订阅路径、JSON/Clash 开关、内容格式、流量信息和更新间隔共用现有设置，不需要重新创建节点。关闭 TCP 订阅后，已启用的 UDP 订阅可继续独立运行。更改监听、证书和开关需要保存并重启面板。

## 使用二维码

在原来能显示订阅二维码的客户端或入站客户端页面中，新增 **HTTP/3（UDP）订阅服务** 项，可以复制或扫描备用链接。入站列表原来只显示节点链接的二维码菜单保持原行为。

链接仍是 HTTPS，例如 `https://sub.example.com:2097/sub/你的订阅ID`。HTTP/3 使用 QUIC/UDP，不使用 `udp://` 订阅格式；二维码只携带链接，不能指示或强制下载器使用 HTTP/3。

应当在原 TCP 订阅还能连接时，把备用链接及备用 UDP 节点导入各设备，并测试。NekoBox 在代理已连接时优先经过本地代理；失效的代理仍开启时，可能不会进入 HTTP/3 直连分支。

## 验证仅通过 UDP 下载

使用支持 HTTP/3 的 curl（`curl -V` 中包含 HTTP3）：

```bash
curl --http3-only --fail --show-error -D - 'https://sub.example.com:2097/sub/你的订阅ID'
```

`--http3-only` 不回退 TCP；应返回 HTTP/3 的成功响应及原有订阅内容。不要把包含订阅 ID 的完整地址或响应公开贴出。面板内开关和二维码显示成功不等于手机客户端已经验证成功，仍需在设备上测试。
