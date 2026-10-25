---
title: "IR Face Authentication for Omarchy"
type: module-readme
date: 2026-10-26
status: active
canonical_path: "/home/eclipse/Documents/Dev/omarchy-program/omarchy-surface-restore/modules/face-auth/README.md"
---

# IR Face Authentication for Omarchy

This module restores local Howdy face authentication on a supported Surface running Omarchy. It integrates with three independent authentication flows: the Omarchy lock screen, optional terminal sudo, and optional graphical Polkit authorization. Password authentication remains available.

The tested hardware baseline is Surface Laptop 5 on Omarchy/Arch. Other Surface camera systems and Omarchy releases are not implied to work. This project is a Howdy/PAM integration, not a Windows Hello-equivalent anti-spoofing or camera power guarantee.

## Install

From the repository root:

```bash
./install.sh check
./install.sh face
```

`./install.sh face` offers one guided transaction for the lock screen, terminal sudo, and graphical Polkit. Use `./install.sh face --all` to choose all three in one run, or specify any combination of `--lock --sudo --polkit`. Howdy is installed/enrolled once and shared by the selected integrations.

### Guided setup panel

The `surface.face-setup` bar widget offers read-only compatibility checks and independent Lock screen, terminal sudo, and graphical Polkit selections. Build and validate its standalone plugin checkout from the repository root:

```bash
python3 modules/face-auth/scripts/export-setup-plugin.py --output /tmp/surface-face-setup
omarchy plugin validate /tmp/surface-face-setup
```

The exported folder is ready to publish as the root of its own Git repository. Once that repository is published, install it with `omarchy plugin add <plugin-git-url> --enable`. The export is currently validated locally; the companion repository and catalog listing are not yet published. Details: [plugin distribution](../../docs/face-setup-plugin-distribution.md).

The installer checks Omarchy, its plugin translation API, stable V4L2 paths and an accessible IR camera. It asks you to identify the camera; it does not guess `/dev/video0`. Review the AUR `howdy-git` transaction. Howdy captures and stores the enrolled face model locally under `/etc/howdy/models/`; the model is never copied into this repository.

After Howdy enrollment, lock-screen face/password integration is installed. On a lit lock screen, manual lock itself does not start the camera; an explicit fresh interaction can request a scan. A confirmed display-off-to-wake or suspend-resume transition waits about 1.5 seconds and requests one scan. Failed attempts do not cause periodic background scanning. Password stays available.

### Optional terminal sudo

```bash
./install.sh sudo-face
```

Only `y`/`Y` after `Use face authentication? [y/N]` starts Howdy. Enter, decline, timeout, unavailable TTY or failed recognition falls through to the existing password flow. `sudo -k -v` can trigger a fresh test by clearing the sudo timestamp.

### Optional graphical administrator prompts

```bash
./install.sh polkit-face
```

This adds explicit face/password choices to Omarchy's fullscreen Polkit prompt. Clicking **Use face** is required before camera access. Cancel ends that authorization. This changes the Polkit PAM service, user plugin, a narrowly scoped camera-device rule, and helper/module files; the installer shows and backs up its targets.

Returning from a password page to the face method requires the face module's patched Quickshell API. The person returns to a quiet method picker; they must choose **Use face** again to consent to scanning. If authentication is already busy, the current Polkit backend can cancel the request or wait for face failure; it cannot switch that busy conversation directly to password.

## UI-only upgrade

For an already configured face setup:

```bash
./install.sh plugin-ui
omarchy restart shell
```

This only updates existing managed lock and Polkit UI resources. It does not edit PAM or Howdy, and it does not enroll a model again. The installed plugins are self-contained and do not require the checkout to remain in place.

The bilingual English/Simplified Chinese interface follows **Omarchy menu → Setup → Language**. The terminal helper reads the standard `~/.config/omarchy/language` preference. Custom XDG config homes are not used by the privileged terminal helper.

## Quickshell requirement

Graphical return-to-face uses `AuthFlow.restartAuthentication()`. The pinned recipe and patches are under [`packaging/quickshell-polkit-restart`](packaging/quickshell-polkit-restart/README.md). The recipe targets the tested Quickshell source revision and must not blindly downgrade a newer system package. Old runtimes keep password authentication and hide unsupported return behavior.

On Qt 6.12 this build must also retain Omarchy's theme-loader compatibility patch. The corrected local package is `0.3.2.r7.g2b4501a-3.1`; the earlier `-2` package omitted that patch and can render other plugins' theme colors incorrectly.

## Verify and recover

Test in this order: lock-screen password fallback; lock → password → return to face picker → explicit face; `sudo -k -v` with n then y; `pkexec /usr/bin/id` with password, return, face, and cancel. Then test one real graphical administrator action. Polkit may cache authorization, so a command may not prompt every time.

Use the one-command uninstaller for a tracked installation:

```bash
./uninstall.sh face
```

It previews the recorded integrations and asks once. Before changing files, the uninstaller compares them with the install-time fingerprints; if a user or another tool changed a managed path later, it stops and lists the conflict so those edits are not overwritten. It restores the exact pre-install files, archives a newly enrolled model in the protected transaction backup by default, and removes Howdy packages only if they were absent before install. Package removal does not cascade; pacman may keep a package if another package now requires it. The uninstaller never removes touchscreen support, linux-surface, iptsd, or Quickshell. It refuses legacy installs without a protected ledger and interrupted installs without a complete fingerprint, rather than inferring ownership from an arbitrary snapshot.

For manual recovery, installers create timestamped backups below `/var/backups/omarchy-surface-restore`. Restore only the face module snapshot when desired:

```bash
./scripts/restore.sh --module face-auth
```

Snapshots from releases before module labels were added are listed only by the unfiltered restore command; review the listed files carefully. Restore does not remove packages or kernels and does not downgrade Quickshell. Keep a working terminal open while restoring authentication files.

## Limits and privacy

- Howdy's PAM matcher is a separate process. Ending the UI/PAM conversation does not prove the matcher immediately exits or releases the camera; the UI timeout is not a hardware power bound.
- Surface Laptop 5 is the real-device baseline. Check a different Surface's camera stack, permissions and IR node independently.
- Do not commit `*.dat`, `*.model`, face images, camera frames, backups, local packages, secrets, or device-specific configuration.

For implementation details and tests, see [plugin behavior](../../docs/plugin-development.md), [local acceptance record](../../docs/local-acceptance-fixes.md), and [repository tests](../../tests/run.sh).
