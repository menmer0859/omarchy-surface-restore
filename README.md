# Surface + Omarchy hardware restore

Restore the touchscreen and IR face unlock on Microsoft Surface devices running Omarchy. The scripts are based on a real Surface Laptop 5 setup, but detect or ask for device-specific values instead of embedding that machine's camera path or biometric model.

中文说明：[README.zh-CN.md](README.zh-CN.md)。完整的 Surface Laptop 5 实测记录：[docs/verified-surface-laptop-5.md](docs/verified-surface-laptop-5.md)。

> Review the scripts before running them. They install packages and write system authentication files. Password authentication remains available; face recognition is an optional convenience layer.

## Tested setup

| Component | Verified reference |
| --- | --- |
| Device | Microsoft Surface Laptop 5 |
| Distribution | Omarchy 4.0.4 on Arch Linux |
| Touchscreen | `linux-surface` 6.19.8 + `iptsd` 3.1.0 |
| IR face authentication | Howdy 2.6.1 development package (`howdy-git`) |
| Lock screen | Omarchy Quickshell lock plugin with separate Howdy PAM service |

Other Surface models and Omarchy releases may differ. The touchscreen path uses the upstream linux-surface Arch repository. The lock-screen clone was tested on Omarchy 4.0.4 and will ask before proceeding on another version.

## Quick start

On an Omarchy Surface desktop, install the basic inspection tools if needed, clone this repository, and review the scripts:

```bash
sudo pacman -S --needed git v4l-utils
git clone https://github.com/menmer0859/omarchy-surface-restore.git
cd omarchy-surface-restore
./install.sh check
less README.md
```

Run the interactive menu:

```bash
./install.sh
```

Or choose a path directly:

```bash
./install.sh touch  # Surface kernel and touchscreen support
./install.sh face   # Howdy, local face enrollment, and lock-screen integration
./install.sh sudo-face  # Optional, consent-gated face auth for terminal sudo
./install.sh all    # Both paths, in sequence
```

The touch path downloads the upstream signing key and checks its fingerprint (`87DEFA4AB94A99A4C8C3112556C464BAAC421453`) before trusting it. It adds the linux-surface package source, then runs a normal Arch system upgrade and installs the Surface kernel, headers, and `iptsd`. Keep the laptop on power. The stock Omarchy kernel stays installed as a fallback. The script does not rewrite Limine entries or reboot the machine.

The face path requires an AUR helper (`yay` or `paru`) and `v4l-utils`. Review the helper's package prompts. The installer lists stable V4L2 paths; use `v4l2-ctl --list-devices` and Howdy's camera test to identify the IR node, then enter its number. If the camera is not in `/dev/v4l/by-path`, stop and investigate device permissions instead of guessing `/dev/video0`. If another user plugin already clones the Omarchy lock plugin, disable it first to avoid two plugins replacing the same lock screen.

Howdy enrollment runs locally and stores the model under `/etc/howdy/models/`. Model files are excluded from Git. The installer makes the selected model readable by the local account that the lock screen runs as, while keeping it root-owned. The lock screen starts in face mode when a model is present and offers a visible button to switch to password. Choosing face again restarts recognition. Password PAM configuration is not edited.

Terminal sudo face authentication is a separate opt-in step. After `face` has enrolled a model, run `./install.sh sudo-face`. Whenever sudo requests authentication, the controlling terminal displays `Use face authentication? [y/N]`; only typing `y` or `Y` starts Howdy. Enter, any other input, timeout, unavailable terminal, or failed recognition continues through the existing password authentication. The setup is limited to `/etc/pam.d/sudo` and the root-owned `/usr/local/libexec/omarchy-sudo-face-consent` helper. It carries the existing faillock pre-authentication and success options into the sudo flow; it does not change `system-auth`, `su`, desktop login, or lock-screen behavior. The sudo PAM file and any replaced helper are backed up. Use `./scripts/restore.sh` to restore them; if the helper did not exist before installation, restore removes it.

#### Verify terminal sudo face authentication

1. Confirm the current account has an enrolled model with `test -s "/etc/howdy/models/$USER.dat"`. If it does not, run `./install.sh face` and enroll locally first.
2. Run `./install.sh sudo-face` from the project directory. Before changing files, it checks the Howdy command and model, the `pam_howdy.so`, `pam_exec.so`, and `pam_faillock.so` modules, and the existing sudo PAM layout. It then shows the change scope and asks for confirmation. The installer backs up `/etc/pam.d/sudo`, installs a root-owned mode `0755` helper under `/usr/local/libexec/`, and updates only sudo's authentication rules.
3. Run `sudo -k -v` to clear sudo's cached authentication and trigger a fresh check. Enter `N`; the normal sudo password prompt should follow. Enter the account password to verify the fallback.
4. Run `sudo -k -v` again and enter `y`. Howdy should start the IR camera. A successful match should authenticate; a failed match should continue to the password prompt.

Sudo caches successful authentication, so the prompt does not appear for every command. `sudo -k` forces a new check. Without a controlling terminal, the helper refuses to start the camera; non-interactive sudo remains subject to sudo's own password and TTY policy.

In the PAM flow, `pam_faillock preauth` checks the account before asking for consent. `pam_exec.so quiet` calls the consent helper and suppresses PAM's user-facing “helper failed” message when the user declines; only `y`/`Y` reaches `pam_howdy.so`. Because `pam_exec` runs the helper in a new session without a controlling `/dev/tty`, the helper opens only the local terminal named by PAM's `PAM_TTY` value. Face success runs `pam_faillock authsucc`; decline or face failure continues through the existing `system-auth` password flow. `[y/N]` means decline is the default, so Enter never starts the camera.

To fully revert the feature, run `./scripts/restore.sh` and choose the snapshot created before sudo face authentication was installed. Re-running the installer makes a newer snapshot. Before selecting one, inspect the backed-up `etc/pam.d/sudo`: choose a snapshot whose file does **not** contain the `omarchy-surface-restore sudo face authentication` marker to disable the feature completely.

## After installation

For touchscreen support, reboot and select the entry containing `linux-surface` in Limine if it is not selected automatically. Confirm the running kernel and IPTS daemon:

```bash
uname -r
systemctl status iptsd.service
```

The kernel version string should contain `surface`. Test touch input on the desktop. If touch does not work, return to the Omarchy kernel from Limine and review `journalctl -b -u iptsd.service`.

For face unlock, reload the Omarchy shell and lock the screen:

```bash
omarchy restart shell
```

The first screen should say “请面向摄像头” and begin recognition. Use “使用密码解锁” to enter the account password; switch back with “使用人脸解锁”. Confirm the fallback password works before relying on face recognition.

## What the installer changes

- Adds the signed `linux-surface` Arch repository and installs `linux-surface`, `linux-surface-headers`, and `iptsd`.
- Installs `howdy-git` through the AUR helper after the user approves the package transaction.
- Sets Howdy's camera path and 480×480 frame size, retaining other Howdy config values.
- Creates the separate `/etc/pam.d/omarchy-lock-face` PAM service.
- Installs the version-tested Quickshell lock plugin into `~/.config/omarchy/plugins/surface.lock/`.
- Saves every overwritten file under `/var/backups/omarchy-surface-restore/<timestamp>/` with its original absolute path preserved.
- Saves the Howdy models directory metadata before changing its access mode, so restore can return its prior owner and permissions.

This Surface Laptop 5 needed a 10-second camera timeout and `dark_threshold = 90` for reliable frame capture. Different cameras and room lighting may need different values; these are left for the user to tune in `/etc/howdy/config.ini`.

## Restore configuration

To restore a saved configuration snapshot:

```bash
./scripts/restore.sh
```

The script lets you select a snapshot, prints the files it will restore, and asks before copying them back. A combined `all` run shares one snapshot; separate touch and face runs create separate snapshots. It also removes individual files the installer recorded as newly created, such as the face PAM service and the newly enrolled model. It does not remove installed packages, kernel images, or the repository signing key. The saved `pacman.conf` can restore the prior repository list. Remove packages or the signing key separately only after confirming the Omarchy kernel boots reliably.

## Privacy and security

- Face enrollment is local. Never commit `*.dat`, camera snapshots, Howdy model archives, package archives, private signing keys, or backup directories.
- Face recognition is not a replacement for the password. Howdy and the additional lock plugin are maintained by separate upstream projects; inspect updates before applying them.
- The Howdy model is sensitive biometric data. Protect backups that contain it and delete the model from the system if you remove face unlock.
- Lock-screen Howdy uses a dedicated PAM service. Terminal sudo face authentication is disabled unless `./install.sh sudo-face` is run, and always requires an explicit terminal `y`/`Y` response before camera access.
- An AUR helper executes third-party build recipes. Review the Howdy PKGBUILD and its dependencies before accepting the transaction.

## Troubleshooting

**Touchscreen remains unavailable**

- Confirm `uname -r` contains `surface`.
- Check `systemctl status iptsd.service` and `journalctl -b -u iptsd.service`.
- Make sure the firmware and Surface kernel packages completed installation. Boot the original kernel if the new kernel fails.

**Howdy cannot open the camera**

- Inspect `v4l2-ctl --list-devices` and `/dev/v4l/by-path/` again; video node numbers can change.
- Run `sudo howdy test` and check the Howdy service logs. A built-in RGB camera is not necessarily the IR camera.
- Confirm the user can traverse `/etc/howdy/models/` and read only their model file. This reference installer sets the model directory to `0711` and the selected model to `0640 root:<user-primary-group>`.
- If the image is consistently too dark or recognition times out, adjust `dark_threshold` and `timeout` for the camera and lighting.

**Lock screen has no face button or still starts in password mode**

- Confirm `/etc/howdy/models/$USER.dat` exists and is readable by the desktop account.
- Confirm `/etc/pam.d/omarchy-lock-face` contains the Howdy PAM module.
- Confirm `~/.config/omarchy/plugins/surface.lock/` has the project manifest and QML files, then run `omarchy restart shell`.
- Check `journalctl --user -b` for `PermissionError`, PAM errors, or plugin load errors. The password PAM service remains the fallback.

## Tests

Run the local checks from the repository root:

```bash
bash tests/run.sh
```

They use temporary files and do not install packages or modify system configuration. A real touchscreen and face-unlock check still requires the target Surface hardware.

## Upstream references

- [linux-surface project](https://github.com/linux-surface/linux-surface)
- [linux-surface Arch installation guide](https://github.com/linux-surface/linux-surface/wiki/Installation-and-Setup#arch)
- [linux-surface supported-device matrix](https://github.com/linux-surface/linux-surface/wiki/Supported-Devices-and-Features)
- [Howdy](https://github.com/boltgolt/howdy)
- [Howdy camera troubleshooting](https://github.com/boltgolt/howdy/wiki/Common-issues)
- [Omarchy](https://github.com/basecamp/omarchy)

## License

MIT. See [LICENSE](LICENSE).
