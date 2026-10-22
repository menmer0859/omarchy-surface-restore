# Omarchy Surface Restore

Choose only the Surface feature you want. This repository is one project with two separately installable modules:

| Module | What it restores | Entry point |
| --- | --- | --- |
| IR face authentication | Omarchy lock-screen face unlock, with separate optional terminal sudo and graphical Polkit integration | `./install.sh face` |
| Touchscreen | linux-surface kernel, headers, and `iptsd` | `./install.sh touch` |

The modules can be installed independently and coexist. Face setup does not install the Surface kernel; touchscreen setup does not configure PAM, Howdy, or face plugins. The legacy `./install.sh all` still runs touchscreen setup followed by initial face setup. It does not enable sudo or graphical face authentication.

## Quick start

```bash
sudo pacman -S --needed git v4l-utils
git clone https://github.com/menmer0859/omarchy-surface-restore.git
cd omarchy-surface-restore
./install.sh check
./install.sh
```

The menu lets you choose a module. You can also start either directly:

```bash
./install.sh face
./install.sh touch
```

Review the module instructions before installation: [IR face authentication](modules/face-auth/README.md) · [Touchscreen](modules/touch/README.md). 中文：[人脸解锁](modules/face-auth/README.zh-CN.md) · [触摸屏](modules/touch/README.zh-CN.md)。

## Verified reference setup

The real-device baseline is a Microsoft Surface Laptop 5 running Omarchy on Arch Linux. The face plugin and module refactor were most recently installed and exercised on this device; other Surface models, camera stacks, and Omarchy versions need their own compatibility checks. Touch support uses the upstream linux-surface Arch repository and `iptsd`.

Read [the verified Surface Laptop 5 setup](docs/verified-surface-laptop-5.md) and [the face plugin development and behavior contract](docs/plugin-development.md). This project combines Howdy, PAM, and Omarchy UI; it does not claim Windows Hello-equivalent anti-spoofing or camera cancellation guarantees.

## Module commands

```bash
./install.sh face        # Initial Howdy enrollment and lock-screen integration
./install.sh sudo-face   # Optional: explicit y/N consent before terminal sudo face scan
./install.sh polkit-face # Optional: explicit button choice in graphical admin prompts
./install.sh plugin-ui   # Upgrade installed face plugin UI only
./install.sh touch       # Surface touchscreen kernel and iptsd
./install.sh check       # Read-only device/runtime summary
./install.sh all         # Legacy: touch, then initial face setup
```

Each installer summarizes system changes, asks before applying them, and records a restore snapshot. See the module README for dependencies, verification and recovery instructions. Face models stay on the local machine and must never be committed.

## Development checks

Run the repository suite from the checkout root:

```bash
bash tests/run.sh
bash modules/face-auth/tests/compile-services.sh
```

The native Polkit restart regression additionally needs the pinned Quickshell source prepared by the face module packaging recipe; see [its packaging guide](modules/face-auth/packaging/quickshell-polkit-restart/README.md).

## License

See [LICENSE](LICENSE).
