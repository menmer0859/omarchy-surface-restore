# Surface Touchscreen Support

This module installs the upstream linux-surface kernel, matching headers, and `iptsd` on an Arch-based Omarchy system. It does not configure Howdy, PAM, face models, lock-screen plugins, or Polkit.

The repository's real-device baseline is Surface Laptop 5. Other Surface touch controllers may need different kernel support; check upstream device compatibility before installing.

## Install

From the repository root:

```bash
./install.sh check
./install.sh touch
```

The installer verifies the upstream linux-surface signing-key fingerprint before trusting it, explains that `pacman -Syu` may update other packages, then asks before adding the repository and installing `linux-surface`, `linux-surface-headers`, and `iptsd`. The stock Omarchy kernel remains installed as a fallback. Keep the device on power during the system upgrade.

## Verify

Reboot and select the `linux-surface` entry in Limine if it was not selected automatically:

```bash
uname -r
systemctl status iptsd.service
```

The running kernel name should include `surface`. Test touch input. If it fails, boot the stock Omarchy kernel and inspect:

```bash
journalctl -b -u iptsd.service
```

## Recover

Touch installation records the changed repository configuration in the shared backup location. To review and restore only a labeled touch snapshot:

```bash
./scripts/restore.sh --module touch
```

Older snapshots without a module label appear only in the unfiltered list; review their saved paths before restoring. Restore does not remove installed kernel packages or signing keys. Remove those separately only after confirming the stock kernel boots reliably.
