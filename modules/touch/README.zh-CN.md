# Surface 触摸屏支持

本模块在基于 Arch 的 Omarchy 上安装上游 linux-surface 内核、匹配的 headers 和 `iptsd`。它不会配置 Howdy、PAM、人脸模型、锁屏插件或 Polkit。

本仓库的实机基线为 Surface Laptop 5。其他 Surface 触摸控制器可能需要不同的内核支持，安装前请核对上游设备兼容性。

## 安装

从仓库根目录运行：

```bash
./install.sh check
./install.sh touch
```

安装器会先核验 linux-surface 上游签名密钥指纹，说明 `pacman -Syu` 可能同时更新其他软件包，再征求同意添加软件源并安装 `linux-surface`、`linux-surface-headers` 和 `iptsd`。原 Omarchy 内核会保留为备用项。系统更新时请连接电源。

## 验证

重启。如果 Limine 没有自动选中，请选择名称包含 `linux-surface` 的启动项：

```bash
uname -r
systemctl status iptsd.service
```

当前内核名称应包含 `surface`，之后测试触摸输入。若触摸无效，改从原 Omarchy 内核启动并检查：

```bash
journalctl -b -u iptsd.service
```

## 恢复

触摸安装会将软件源配置变化保存在共享备份位置。查看并只恢复带有 touch 标签的快照：

```bash
./scripts/restore.sh --module touch
```

没有模块标签的旧快照只出现在不筛选的恢复列表里；恢复前请检查保存路径。恢复不会卸载已安装的内核软件包或签名密钥。确认原内核可稳定启动后，再单独决定是否移除它们。
