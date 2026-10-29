# 3x-ui SG 定制版

本仓库基于 [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) 定制，保留原项目许可证及作者署名。

当前默认稳定版为 **v3.1.0-sg3**。基于官方 v3.11.0 的 **v3.11.0-sg1** 是独立测试版，保留新版功能和多语言，移除面板广告，并按需求调整菜单。

## 默认稳定版安装或覆盖更新

```bash
bash <(curl -fLsS https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/main/install.sh)
```

已有安装会进入保留数据的覆盖更新流程，不需要卸载。

## v3.11.0-sg1 测试版

测试安装、已有面板覆盖更新和完整备份回退方法见 [测试版说明](RELEASE-SG311.md)。请先在测试服务器验证。

- [SG3 稳定版](https://github.com/ShiGuangDe/3x-ui-sg/releases/tag/v3.1.0-sg3)
- [v3.11.0-sg1 测试版](https://github.com/ShiGuangDe/3x-ui-sg/releases/tag/v3.11.0-sg1)
- [上游项目文档](https://docs.sanaei.dev/)

本次测试版不包含 UDP 订阅实验功能，不会自动替换默认稳定版。
