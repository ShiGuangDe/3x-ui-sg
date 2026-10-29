# v3.11.0-sg1 测试版

基于官方 v3.11.0。此版本为预发布测试版；SG3 继续作为默认稳定版，通用安装命令不会自动升级到本测试版。

## 改动

- 移除登录页、系统状态页广告，移除赞助商页面、广告组件、后台拉取接口和图片代理。
- 删除电脑、手机菜单中的书本和爱心入口，保留多语言、主题和侧边栏固定功能。
- 路由页默认显示路由规则；标签顺序为路由规则、基本路由、路由测试。
- 高级配置移为独立菜单，位于路由与面板设置之间；旧链接继续可用。
- 简体中文界面中，节点改为服务器、主机页面改为订阅主机。
- 面板版本链接指向本仓库对应发布页，Xray 内核版本单独显示。
- 保留双渠道脚本更新、SHA256 校验、更新前完整备份和失败自动恢复。
- 保留官方 v3.11.0 的功能与修复，包括 Hysteria2 指纹 None 的保存修复；不包含已撤销的 UDP 订阅功能。

## 全新测试安装

在测试服务器以 root 执行，按提示完成初始配置：

```bash
curl -fL https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/v3.11.0-sg1/install.sh -o /root/3x-ui-sg-test-install.sh && bash /root/3x-ui-sg-test-install.sh v3.11.0-sg1
```

全新安装使用官方 v3.11.0 配套的 Xray v26.10.21。请用自己的 v2rayN、NekoBox、小火箭验证实际连接。

## 已有面板覆盖更新

无需卸载。以下命令在后台执行，SSH 断开后仍会继续：

```bash
if curl -fL https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/v3.11.0-sg1/update.sh -o /root/3x-ui-sg-test-update.sh; then
  nohup bash /root/3x-ui-sg-test-update.sh sg v3.11.0-sg1 > /root/sg311-update.log 2>&1 < /dev/null &
fi
```

查看结果：

```bash
tail -n 80 /root/sg311-update.log
/usr/local/x-ui/x-ui -v
systemctl is-active x-ui
```

更新期间会短暂重启面板。原有账号、节点、证书、端口与路径保留；原有 Xray 内核及地理文件不覆盖，缺失的 MTProto 配套程序按需补充。需要新版内核的协议功能，应在完成客户端兼容测试后再通过面板单独升级内核。

备份保存在日志显示的 `/var/backups/x-ui-sg/v3.11.0-sg1-日期.随机字符` 目录。备份包含程序、管理脚本、数据库及原程序目录中的文件；外部证书和自定义路径不移动。

## 回退到升级前的 SG3

必须使用**本次从 SG3 升级时生成的完整备份**，不能只装回 SG3 二进制并继续使用新版数据库。把下面目录替换为更新日志中对应的备份目录：

```bash
nohup bash /root/3x-ui-sg-test-update.sh rollback /var/backups/x-ui-sg/v3.11.0-sg1-日期.随机字符 > /root/sg311-rollback.log 2>&1 < /dev/null &
```

```bash
tail -n 80 /root/sg311-rollback.log
/usr/local/x-ui/x-ui -v
systemctl is-active x-ui
```

回退会恢复升级前的程序和数据库，因此升级后新增或修改的数据不会出现在旧数据库中。执行恢复前还会保存当前状态的安全备份。全新安装此测试版的服务器没有旧版数据库备份，不能用此方法凭空恢复 SG3 数据。

## 后续更新

运行 `x-ui update` 可选择 SG 定制版或官方版。SG 默认渠道仍指向最新正式版；测试版不会自动降级到 SG3。切换到官方版会替换定制功能。

本发布不操作任何用户服务器，也不将本测试版设为 Latest。
