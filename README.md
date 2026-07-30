[中文](./README.md) | [版本镜像说明](./PINNED-MIRROR.md) | [sg1 稳定版](https://github.com/ShiGuangDe/3x-ui-sg/releases/tag/v3.1.0-sg1) | [sg2 新版](https://github.com/ShiGuangDe/3x-ui-sg/releases/tag/v3.1.0-sg2)

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="./media/3x-ui-dark.png">
    <img alt="3x-ui" src="./media/3x-ui-light.png">
  </picture>
</p>

[![Stable Version](https://img.shields.io/badge/stable-v3.1.0--sg1-blue.svg)](https://github.com/ShiGuangDe/3x-ui-sg/releases/tag/v3.1.0-sg1)
[![Latest Version](https://img.shields.io/badge/latest-v3.1.0--sg2-success.svg)](https://github.com/ShiGuangDe/3x-ui-sg/releases/tag/v3.1.0-sg2)
[![Mirror](https://img.shields.io/badge/mirror-self--contained-success.svg)](https://github.com/ShiGuangDe/3x-ui-sg)
[![License](https://img.shields.io/badge/license-GPL%20V3-blue.svg?longCache=true)](https://www.gnu.org/licenses/gpl-3.0.en.html)

**3X-UI** 是一个基于网页的 Xray-core 控制面板，用来配置和监控各种 VPN / 代理协议。

本仓库是在 [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) 基础上做的**二次开发分支（fork）**，目标是让"搭协议"这件事**点几下就能完成**：内置一键协议模板、中转、多服务器下发、批量管理、扫码导入等功能，界面做了中文化优化。

> [!IMPORTANT]
> 本项目仅供个人学习与通信使用，请勿用于任何非法用途，也不建议用于生产环境。

> [!NOTE]
> 这是包含 `v3.1.0-sg1` 与 `v3.1.0-sg2` 的**版本化独立镜像**。源码、安装脚本和 8 个二进制 Release 资产均保存在
> [ShiGuangDe/3x-ui-sg](https://github.com/ShiGuangDe/3x-ui-sg)，安装过程不会查询
> 其他作者仓库的 `latest`，也不会从 `Teminuosi/3x-ui` 下载面板资源。每个面板显示自身的 SG 版本号，
> 侧栏版本链接会打开本仓库中对应的 Release。

---

## 快速开始（可选 sg1 / sg2）

在你的 VPS（Debian / Ubuntu / CentOS 等）上，以 `root` 执行。推荐使用下面的引导式自动安装：
数据库使用 SQLite、面板使用随机端口。脚本会先让你选择面板版本，再选择证书模式。

```bash
bash <(curl -fLs https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/v3.1.0-sg2/install.sh)
```

版本菜单：

1. **v3.1.0-sg1**：原稳定版界面。
2. **v3.1.0-sg2**：新版系统状态、独立路由/出站入口和完整中文化，默认选项。

安装到 SSL 阶段时选择：

1. **有域名**：脚本会要求输入已经解析到当前 VPS 的域名，并申请、安装 90 天域名证书。
2. **没有域名**：脚本自动检测公网 IPv4，并申请、安装约 6 天有效的 Let’s Encrypt IP 证书；acme.sh
   会自动续期。

两种模式都要求公网 **80 端口**能够到达这台 VPS。证书申请失败时，脚本会重新启动面板并明确打印
可用的 `http://IP:端口/路径`，不会再错误地显示无法打开的 HTTPS 地址；之后可以在 `x-ui` 菜单中重试证书。

装完后，在服务器上输入 `x-ui` 即可打开管理菜单（重启面板、查看账号、修改端口、配置 SSL、卸载等）。
安装器只允许选择本仓库已经发布的 SG 版本，不会自动跟随其他仓库的最新版本。

> - 需要完全无人值守时，可以预先指定模式：
>   ```bash
>   # 域名证书（把域名替换成自己的）
>   XUI_AUTO=1 XUI_VERSION=v3.1.0-sg2 XUI_SSL_MODE=domain XUI_DOMAIN=panel.example.com \
>     bash <(curl -fLs https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/v3.1.0-sg2/install.sh)
>
>   # 公网 IP 证书
>   XUI_AUTO=1 XUI_VERSION=v3.1.0-sg1 XUI_SSL_MODE=ip \
>     bash <(curl -fLs https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/v3.1.0-sg2/install.sh)
>   ```
> - 也可以把版本作为第一个参数传入：
>   ```bash
>   bash <(curl -fLs https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/v3.1.0-sg2/install.sh) v3.1.0-sg1
>   bash <(curl -fLs https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/v3.1.0-sg2/install.sh) v3.1.0-sg2
>   ```
> - 如果 shell 中的行内环境变量没有生效，可以先下载脚本再执行：
>   ```bash
>   curl -fL https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/v3.1.0-sg2/install.sh -o /tmp/3x-ui-sg.sh
>   XUI_AUTO=1 XUI_VERSION=v3.1.0-sg2 bash /tmp/3x-ui-sg.sh
>   ```

### 更新边界 / 卸载

```bash
x-ui             # 打开管理菜单
x-ui update      # 明确确认后，转为官方 MHSanaei/3x-ui 最新版
```

Web 面板内的“面板更新”已锁定：它不会查询 `Teminuosi/3x-ui`，不会再显示 qs14 等版本，也不能从网页
触发 qs 分支更新。服务器上的 `x-ui update` 则特意保留为迁移出口：执行前会明确警告，确认后直接使用
[MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) 官方更新脚本。这样会离开 SG 定制版并替换成官方最新版，
但不会删除原有数据库。`Update Menu` 和 `Legacy Version` 同样使用官方 MHSanaei 仓库。

需要卸载时，在 `x-ui` 菜单中选择 **Uninstall**。以后重新执行安装命令时，可以再次选择 `sg1` 或 `sg2`。

---

## 本分支相比原版做了哪些改动

下面这些是本 fork 在上游 3x-ui 之上**新增 / 改造**的功能：

### 📊 新版系统状态与中文导航
- 「系统状态」采用新版信息面板布局：集中显示 CPU、内存、交换空间、存储、实时上下行速度、连接数、运行时间和 IP 信息。
- 「路由规则」与「出站规则」已从「Xray 设置」拆分为侧边栏独立入口，位于「面板设置」上方，常用配置不必再进入多层标签页。
- 侧边栏统一使用「分组」「服务器」等中文名称，并补齐简体中文界面中缺失的客户端、分组、日志和设置词条。
- 面板版本入口按当前运行版本指向本仓库的 `sg1` 或 `sg2` Release，不会重新启用其他分支的网页更新。

### 🚀 一键协议模板（推荐协议）
- "添加入站"弹窗顶部有 **推荐协议** 开关，默认开启：直接出现模板画廊，点一下就填好一整套可用配置。
- 内置 5 个主流模板：
  - **VLESS + Reality（Vision）** — 主力首选，免证书、抗封锁强（推荐）
  - **VLESS + Reality（gRPC）** — Reality 的 gRPC 变体，免证书
  - **Trojan + TLS** — 经典 TLS 伪装，需域名+证书
  - **VMess + WS + TLS** — 可走 CDN 中转，需域名+证书
  - **Hysteria2** — 基于 QUIC，速度快，需域名+证书（注意需 sing-box / NekoBox 客户端，Xray 内核不支持）
- **一键添加全部推荐**：一次性把所有可用模板都建好。面板已配好域名证书时建全部 5 个；没配证书时只建 2 个免证书的 Reality。
- 关闭"推荐协议"开关即回到完整的手动配置（协议 / 流 / 安全 / 嗅探 / 高级）。

### 🔀 中转（落地分流）
- "添加中转"按钮：入口服务器 → 落地服务器分流。
- 落地端**粘贴分享链接即可自动识别填入**（支持 vless / vmess / trojan / shadowsocks / socks / http），也可手动填写。
- 自带**连通性测试**：建完后点测试，能看到入口到落地的延迟，确认链路通不通。
- 入口默认用免证书的 Reality，自动创建入口入站 + 落地出站 + 路由规则。

### 🖧 多服务器部署（部署到）
- 在「服务器」页注册远程服务器后，添加入站时可选 **部署到** 哪台服务器（含一键模板和「一键添加全部推荐」）。
- 离线服务器会显示但灰掉不可选。

### 📋 入站 / 客户端列表增强
- **批量删除**：入站列表支持勾选 + 批量删除，并在删除时提示一并清理"孤儿客户端"（删除后不再归属任何入站的客户端）。
- **来源标识**：入站列表给中转入口打"中转"标签；客户端列表显示来源（中转 / 入站 / 独立）并支持筛选。
- **行内二维码**：每条入站直接显示**协议二维码**（多客户端则每个客户端一个），手机用小火箭等客户端直接扫码导入，不再只能复制链接。

### 🔗 共享订阅
- 推荐模板 / 一键创建的节点共用同一个订阅 ID，**一个订阅链接即可聚合全部节点**，导入客户端一次到位。

### 🈶 中文化
- "节点"统一改称"**服务器**"等界面用词优化（仅显示文案）。

> 上游原有的 SQLite / PostgreSQL 双数据库、Docker 部署等能力均保留，见下文。

---

## 常用操作指引

**搭一个协议（最常用）**
1. 左侧「入站列表」→「添加入站」。
2. 顶部「推荐协议」保持开启 → 在模板画廊点一个（默认已选中推荐的 VLESS+Reality）。
3. 只需填：备注、总流量（可留 0 = 不限）、流量重置、到期时间。
4. 点「创建」→ 回到列表，点该行的二维码图标，手机扫码导入客户端即可。

**搭中转**
1. 「入站列表」→「添加中转」。
2. 落地框粘贴落地服务器的分享链接（自动识别），或手动填写。
3. 点「测试」确认入口到落地连通（有延迟即代表通）。
4. 点「创建」，会自动建好入口入站、落地出站与路由规则。

**一个订阅管理全部**
- 用「推荐协议 / 一键添加全部推荐」创建的节点共用一个订阅链接；把该订阅地址导入客户端，即可一次性同步所有节点。

---

## 数据库选项

3X-UI 支持两种数据库后端，安装时选择：

- **SQLite**（默认）—— 单文件 `/etc/x-ui/x-ui.db`，零配置，适合中小规模部署。
- **PostgreSQL** —— 适合客户端数量大或多服务器场景。安装脚本可帮你本地装好 PostgreSQL，或填入已有数据库的 DSN。

运行时通过环境变量选择后端（安装脚本会写入 `/etc/default/x-ui`）：

```
XUI_DB_TYPE=postgres
XUI_DB_DSN=postgres://xui:password@127.0.0.1:5432/xui?sslmode=disable
```

### 把现有 SQLite 迁移到 PostgreSQL

```bash
x-ui migrate-db --dsn "postgres://xui:password@127.0.0.1:5432/xui?sslmode=disable"
# 然后在 /etc/default/x-ui 中设置 XUI_DB_TYPE 与 XUI_DB_DSN，重启：
systemctl restart x-ui
```

迁移不会动原 SQLite 文件；确认新后端无误后再手动删除。

### Docker

默认 `docker compose up -d` 仍使用 SQLite。要使用内置的 PostgreSQL 服务，取消 `docker-compose.yml` 中两行 `XUI_DB_*` 环境变量的注释，并以 profile 启动：

```bash
docker compose --profile postgres up -d
```

---

## 致谢与开源协议

- 本项目基于 [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui)（GPL-3.0）二次开发，遵循 **GPL-3.0** 协议开源。
- 特别感谢 [alireza0](https://github.com/alireza0/)。
- 路由规则致谢：[Iran v2ray rules](https://github.com/chocolate4u/Iran-v2ray-rules)（GPL-3.0）、[Russia v2ray rules](https://github.com/runetfreedom/russia-v2ray-rules-dat)（GPL-3.0）。
