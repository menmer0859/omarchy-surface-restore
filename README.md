---
title: "Omarchy Surface Restore"
type: project-readme
date: 2026-10-26
status: reviewed
canonical_path: "https://github.com/menmer0859/omarchy-surface-restore/blob/main/README.md"
---

<div align="center">

<img src="https://raw.githubusercontent.com/menmer0859/omarchy-surface-restore/2b3ba16494986dcf157dc5e980751fee9353a241/docs/images/readme/mark.svg" width="88" alt="Omarchy Surface Restore: a smiling face inside scan corners">

# Omarchy Surface Restore

### Face unlock and touch, back on Surface.

**Restore IR face authentication and touch with two independent Omarchy modules.**<br>
Lock screen, optional sudo and Polkit. Verified hardware baseline: Surface Laptop 5.

<img src="https://raw.githubusercontent.com/menmer0859/omarchy-surface-restore/2b3ba16494986dcf157dc5e980751fee9353a241/docs/images/readme/platforms.svg" width="292" alt="For Omarchy on Arch Linux. MIT license.">

**[Agent install](#install-with-your-agent)** · **[Manual install](#quick-start)** · **[Features](#what-you-get)** · **[Compatibility](#compatibility-and-evidence)** · **[Docs](#documentation-and-file-index)** · **[Issues](https://github.com/menmer0859/omarchy-surface-restore/issues)** · **English** · [简体中文](https://github.com/menmer0859/omarchy-surface-restore/blob/main/README.zh-CN.md)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/menmer0859/omarchy-surface-restore/2b3ba16494986dcf157dc5e980751fee9353a241/docs/images/readme/overview-en-dark.svg">
  <img src="https://raw.githubusercontent.com/menmer0859/omarchy-surface-restore/2b3ba16494986dcf157dc5e980751fee9353a241/docs/images/readme/overview-en-light.svg" width="900" alt="Authentication flow illustration: wake the lock screen for one face attempt, opt into sudo with y, or choose face in a graphical administrator prompt; password remains available.">
</picture>

<sub>Interaction overview, illustrated. Verified hardware baseline: Surface Laptop 5.</sub>

</div>

## TL;DR

Install face authentication, touchscreen support, or both on a Surface running Omarchy. Face authentication covers the lock screen and optional sudo/Polkit requests, with password fallback. The confirmed reference device is Surface Laptop 5; check compatibility before installing on another model.

- **Face authentication:** one module for the lock screen, with optional terminal sudo and graphical Polkit integrations.
- **Touchscreen support:** a separate module using linux-surface and iptsd.
- **A familiar choice:** use your face when appropriate, with password authentication available as fallback.
- **English and Chinese:** graphical interfaces follow Omarchy's language setting; the sudo helper reads the same preference.

Choose the module you need. If touch already works, you can install face authentication on its own. Check [compatibility](#compatibility-and-evidence) before installing on another Surface model.

## Compatibility and evidence

The real-device reference is **Surface Laptop 5 running Omarchy 4.5.0rc1 on Arch Linux**. Lock-screen, terminal sudo, and graphical authorization have received multiple rounds of local testing. This is a specific tested setup, rather than a guarantee for every Surface.

| Area | Current scope |
| :-- | :-- |
| Surface Laptop 5 | **Confirmed:** reference hardware for face authentication and touch |
| Other Surface models | **Unverified:** check camera drivers, usable IR stream, permissions, and upstream touch support individually |
| Omarchy releases | **Unverified beyond the baseline:** require compatible plugin and translation APIs; verify newer releases before relying on them |
| Graphical authorization | **Confirmed scope:** Polkit requests handled by Omarchy's authentication agent |
| Other authentication | **Outside scope:** disk encryption, app vaults, SSH, and other login paths are outside the default integrations |

See the [verified setup](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/verified-surface-laptop-5.md) for device and runtime details.

Evidence: [verified device record](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/verified-surface-laptop-5.md), [behavior contract](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/plugin-development.md), and [current main snapshot a0a55d1](https://github.com/menmer0859/omarchy-surface-restore/commit/a0a55d12ae91e6131a4a91020e023cea784f89a4). [PR #5](https://github.com/menmer0859/omarchy-surface-restore/pull/5) records the setup-widget changes in the repair branch; [snapshot 0dd507e](https://github.com/menmer0859/omarchy-surface-restore/commit/0dd507e772b3c0752fa5d56e93fa40ca928980a8) contains that implementation. It remains pending integration into `main`.

## Install with your agent

Open Codex, Claude Code, or another agent with terminal access **on your Surface running Omarchy**, then copy the entire prompt below. You do not need to know the installation commands. The agent will ask which features you want and guide you through setup; administrator authentication and face enrollment happen locally on your device.

```text
Help me install features from this project on my Surface running Omarchy:
https://github.com/menmer0859/omarchy-surface-restore

First ask whether I want IR face authentication, touchscreen support, or both.
For face authentication, ask separately about lock screen, terminal sudo,
and graphical administrator prompts. Install only the options I select.

Detect my actual Surface model, architecture, Omarchy version, camera support,
and existing configuration. Read the current repository README, selected module
guides, and installer scripts before proceeding. Use a clean checkout and the
project's installation entry points. Surface Laptop 5 is the tested baseline;
check other hardware rather than assuming it is supported.

Explain the system changes before applying them, preserve password fallback,
and use the project's backup and recovery mechanisms. Keep sudo and graphical
face authentication behind explicit user consent. Guide me through camera
selection, package review, and local enrollment when needed.

Let me enter system passwords in my local terminal, never in chat. If your
execution environment blocks privileged installation, give me the exact
commands to run in a normal system terminal without weakening protections.

After installation, guide me through hands-on tests of each selected feature,
including password fallback and any required reboot. Distinguish automated
checks from tests I have actually confirmed. Report what works, what remains
unverified, and how to recover the previous configuration.
```

<sub>A cloud agent without access to this device can explain the steps, but hardware checks, installation, and enrollment require the local Surface.</sub>

## Quick start

### One-line Bash installation

On the Surface, run this command to fetch a clean project checkout and start the guided installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/menmer0859/omarchy-surface-restore/main/scripts/quick-install.sh) face
```

Choose lock screen, terminal sudo, and graphical Polkit separately when prompted. Add `--all` to select all three, or pass any combination of `--lock --sudo --polkit`. The installer keeps its checkout at `~/.local/share/omarchy-surface-restore`, which is also used by the one-line uninstaller below. The bootstrap refuses to overwrite an unrelated or locally modified checkout.

To install touchscreen support instead, replace `face` with `touch`. Use `all` to install both modules in one guided run; their configuration remains independent, and removing face authentication does not remove touch support.

After a tracked face-auth install, remove its integrations with one command:

```bash
bash "$HOME/.local/share/omarchy-surface-restore/uninstall.sh" face
```

The uninstaller restores recorded configuration and archives a newly enrolled model in the protected backup. It does not remove touchscreen support, linux-surface, iptsd, or Quickshell. Legacy installations without a trusted transaction record require manual review.

The bootstrap uses the current `main` branch over HTTPS. To inspect the checkout before running its installer, use the manual steps below.

**1 · Get the source and check your device.**

```bash
sudo pacman -S --needed git v4l-utils
git clone https://github.com/menmer0859/omarchy-surface-restore.git "$HOME/.local/share/omarchy-surface-restore"
"$HOME/.local/share/omarchy-surface-restore/install.sh" check
```

**2 · Choose a module.** Run the installer and select face authentication or touchscreen support. Review its prompts before applying system changes.

```bash
"$HOME/.local/share/omarchy-surface-restore/install.sh"
```

Face setup is one transaction: `./install.sh face` asks which integrations to install (lock screen, terminal sudo, graphical Polkit); `./install.sh face --all` selects all three, or pass any combination of `--lock --sudo --polkit`. It asks you to select the IR camera, review the Howdy package, and enroll your face locally. Touch setup remains a separate module and installs the linux-surface kernel, headers, and iptsd; reboot into that kernel afterward.

**3 · Verify password fallback, then face authentication.** Test the lock screen first, then the selected sudo and Polkit paths:

```bash
sudo -k -v               # Test terminal authentication: try n, then y
pkexec /usr/bin/id       # Test a graphical Polkit request
```

To remove the tracked face setup in one step, run `"$HOME/.local/share/omarchy-surface-restore/uninstall.sh" face`. It previews the tracked integrations, asks once, restores recorded files, and archives a newly enrolled model under `/var/backups/omarchy-surface-restore/`. It does not remove touchscreen support, linux-surface, iptsd, or Quickshell. Installs made before transaction tracking was added are not guessed or automatically removed.

<sub>Prefer direct commands? Use <code>"$HOME/.local/share/omarchy-surface-restore/install.sh" face</code> or <code>"$HOME/.local/share/omarchy-surface-restore/install.sh" touch</code>. Installation and recovery details: <a href="https://github.com/menmer0859/omarchy-surface-restore/blob/main/modules/face-auth/README.md">face authentication</a> · <a href="https://github.com/menmer0859/omarchy-surface-restore/blob/main/modules/touch/README.md">touchscreen</a>.</sub>

## What you get

### Wake, look, unlock

Manual locking secures the session without immediately scanning the face still in front of the camera. After a confirmed screen wake or resume, the lock screen waits about 1.5 seconds and requests one face attempt. Failure leaves you in control: retry or use a password.

There is no periodic background scan loop. On a lit lock screen, a fresh deliberate interaction can request a face attempt. Choosing password suppresses face recognition while that screen stays lit.

### Approve sudo in the terminal

Each fresh sudo authentication asks before using your face. Entering `y` starts recognition and displays guidance toward the laptop camera. Declining, timing out, or failed recognition continues to password authentication.

| Your response | What happens |
| :-- | :-- |
| `y` or `Y` | Attempt face recognition |
| `n`, Enter, or no response | Continue with the password |
| Recognition fails | Continue with the password |

### Choose how to authorize apps

Omarchy's graphical Polkit prompt presents the operation, administrator account, and **Use face / Use password** choices. The camera starts after choosing face. Cancel ends the authorization request.

Returning from password to the face method picker requires the compatible Quickshell build. The [face module guide](https://github.com/menmer0859/omarchy-surface-restore/blob/main/modules/face-auth/README.md#quickshell-requirement) explains that dependency and the limits on switching during an active scan. Applications with their own vault or master password need their own integration.

### Restore the touchscreen separately

The touch module installs the upstream linux-surface kernel, matching headers, and iptsd. The stock Omarchy kernel remains installed as a boot fallback. The face module leaves your kernel choice alone.

| Module | Components it configures |
| :-- | :-- |
| Face authentication | Howdy, selected PAM services, Omarchy lock and authorization UI |
| Touchscreen | linux-surface repository, kernel, headers, and iptsd |

### Configure through Omarchy

A bilingual setup widget checks readiness and lets you select lock screen, sudo, and Polkit independently. Its checks inspect configuration without starting the camera.

The bilingual setup widget and its standalone export are included in `main`. **There is still no published `omarchy plugin add` URL:** the companion plugin repository and catalog listing remain separate follow-up work. Use the source installer above; see the [distribution guide](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/face-setup-plugin-distribution.md) for the current status.

<details>
<summary>For maintainers: build and validate the plugin export</summary>

These commands use the current `main` branch in a separate checkout. Choose a new or empty export directory:

```bash
git clone --branch main https://github.com/menmer0859/omarchy-surface-restore.git "$HOME/.local/share/omarchy-surface-restore-dev"
python3 "$HOME/.local/share/omarchy-surface-restore-dev/modules/face-auth/scripts/export-setup-plugin.py" --output /tmp/surface-face-setup
omarchy plugin validate /tmp/surface-face-setup
```

</details>

## Privacy and recovery

Face matching uses Howdy locally. Enrolled models stay under `/etc/howdy/models/`; keep models, camera frames, and system backups out of issues and commits.

### Risks and open questions

| Question | Answer |
| :-- | :-- |
| Does face recognition start automatically for sudo or apps? | Only after explicit terminal or button consent. Lock/wake follows the behavior described above. |
| Is this equivalent to Windows Hello security? | No equivalent anti-spoofing assurance is claimed. This project integrates Howdy, PAM, and Omarchy. |
| Does cancelling guarantee the camera stops immediately? | Ending a UI/PAM request does not prove the separate Howdy matcher has released the camera. |
| Can I restore the previous configuration? | Installers record snapshots under `/var/backups/omarchy-surface-restore`. Review and restore the relevant module snapshot. |

**Known limitation:** immediate matcher/camera release is not guaranteed. **Unverified:** other Surface models and other Omarchy versions. **Pending:** publication of the standalone plugin repository and its catalog listing. The [behavior contract](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/plugin-development.md) and [distribution guide](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/face-setup-plugin-distribution.md) document these boundaries.

### Restore the previous configuration

Keep a working terminal open while changing authentication settings. To review face-module recovery snapshots:

```bash
"$HOME/.local/share/omarchy-surface-restore/scripts/restore.sh" --module face-auth
```

Restore recovers saved configuration; it does not remove packages or downgrade kernels or Quickshell. Removing the setup widget alone also leaves system authentication configuration installed.

For a Bash-installed face-auth transaction, use the one-command uninstaller described in Quick start. It removes only recorded face-auth changes and retains a newly enrolled model in the protected backup.

## Contributing

Report reproducible problems through [GitHub Issues](https://github.com/menmer0859/omarchy-surface-restore/issues). Include the Surface model, Omarchy and Quickshell versions, affected authentication path, and redacted diagnostics. For another Surface model, both success reports and precise failure reports help improve the compatibility record.

For development checks, run `bash "$HOME/.local/share/omarchy-surface-restore/tests/run.sh"`. The [plugin guide](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/plugin-development.md#verification) explains additional runtime checks.

Built on [linux-surface](https://github.com/linux-surface/linux-surface), [Howdy](https://github.com/boltgolt/howdy), and Omarchy's plugin interfaces. This is a community integration.

## Documentation and file index

| Guide | What you will find |
| :-- | :-- |
| [Face authentication](https://github.com/menmer0859/omarchy-surface-restore/blob/main/modules/face-auth/README.md) | Installation, optional integrations, upgrades, and recovery |
| [Touchscreen](https://github.com/menmer0859/omarchy-surface-restore/blob/main/modules/touch/README.md) | Kernel installation, reboot verification, and recovery |
| [Plugin behavior](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/plugin-development.md) | Lock/wake rules, UI interactions, languages, and known limits |
| [Plugin distribution](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/face-setup-plugin-distribution.md) | Standalone export and publishing status |
| [Local acceptance](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/local-acceptance-fixes.md) | Previously fixed issues and manual retest scenarios |
| [Quickshell packaging](https://github.com/menmer0859/omarchy-surface-restore/blob/main/modules/face-auth/packaging/quickshell-polkit-restart/README.md) | Return-to-face support and the compatible runtime build |

## License

[MIT](https://github.com/menmer0859/omarchy-surface-restore/blob/main/LICENSE).
