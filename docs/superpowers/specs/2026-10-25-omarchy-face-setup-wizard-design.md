# Omarchy Face Authentication Plugin Setup Design

## Intent

Make Surface face authentication discoverable and installable through Omarchy's plugin flow, then guide a user through system readiness and optional authentication integrations without asking them to copy complex shell commands. Keep the existing repository as the development source of truth and export a self-contained, symlink-free Omarchy setup plugin that can be installed with `omarchy plugin add <git-url> --enable`.

## Goals

- Provide a bilingual, Omarchy-themed setup panel with clear readiness for IR camera, Howdy/model, lock PAM, sudo PAM, and graphical Polkit.
- Let the user choose lock screen, terminal sudo, and graphical Polkit independently.
- Keep password authentication as a required fallback and never activate the replacement lock service before the face/PAM setup and password fallback have been verified.
- Launch the existing reviewed system installer flow from the panel so package review, system authentication, camera selection, and face enrollment remain explicit. The user should not have to type or understand shell commands.
- Generate a root-manifest plugin export containing regular files only; validate it using Omarchy's plugin validator and add a regression check for missing symlinks/files.
- Keep touchscreen installation independent.
- Submit the preceding Quickshell repair `be51657` in its own PR; leave merge to the user.

## Non-goals

- Claim an official Omarchy marketplace listing. `omarchy plugin add` accepts a Git URL and does not provide a central searchable catalog.
- Replace Howdy, PAM, Polkit, or system package management with a new authentication backend.
- Perform package installation, PAM writes, face enrollment, or camera access merely by adding/enabling the setup UI.
- Automatically enable sudo or Polkit authentication; each is opt-in.
- Support arbitrary Surface models without device evidence or claim Windows Hello anti-spoofing equivalence.

## Constraints and Existing Behavior

- Omarchy plugin add validates one plugin manifest at the repository root and rejects symlinks anywhere in the plugin tree.
- The project is a modular monorepo, so its current root cannot be passed directly to `omarchy plugin add`.
- `surface.lock` clones the protected native `omarchy.lock` authentication service. A clone activates by role; a different plugin ID does not make a competing lock clone safe.
- The current lock service refuses lock requests if its password PAM service is absent. Therefore it must only be installed/activated after readiness checks pass.
- Howdy is installed from AUR and face enrollment is local. These steps require explicit review/consent and may need a terminal for the existing interactive package and enrollment prompts.
- The verified device baseline is Surface Laptop 5 on Omarchy 4.5.0rc1; other Surface hardware must be reported as unverified.
- Root-owned PAM/helper changes remain in the existing installers with snapshot/restore behavior. Removing a user plugin alone must never be described as rolling those changes back.
- Polkit return-to-face requires the compatible Quickshell package; without it, password fallback remains available.

## Approaches Considered

1. **README-only quick-start commands.** Small and low risk, but does not provide Omarchy plugin lifecycle or an in-shell guided setup.
2. **Exported setup plugin plus existing system installer backend (chosen).** Keep one source tree, build a regular-file plugin export with a root manifest, and let a bilingual panel run checks and launch the existing reviewed installer flow for selected integrations. This reuses tested system logic and adds a native plugin entry point without silently moving privileged logic into QML.
3. **Turn the complete repository into the plugin root.** Rejected because it would undermine the separately installable touch and face modules and current root installer interface.

## User Flow

1. User adds the published setup plugin using Omarchy's plugin add flow and enables its setup panel.
2. The panel explains that plugin code runs in the shell, shows the source/release identity, and offers an environment check.
3. The check reports Omarchy version, camera-path availability/access, existing Howdy/model, existing lock PAM, clone conflicts, sudo state, Polkit state, and whether the compatible Quickshell feature is available. The check itself does not open the camera or request credentials.
4. User selects lock screen (required for face-lock setup), and optionally sudo and/or graphical Polkit. The panel states that password fallback remains enabled.
5. “Configure selected features” launches the existing installer in a terminal with the selected choices. It preserves the current camera selection, AUR review, sudo authentication, enrollment, consent-gated sudo, Polkit, and snapshot behavior. Cancellation or failure returns the user to the panel and does not enable unverified clones.
6. The final readiness check confirms the password PAM service and selected components before enabling/restarting the lock/authentication services. Face attempts are still only initiated by the existing consent and lock/wake behavior.

## Distribution and Updates

- Add a deterministic exporter in the main repository to create a self-contained plugin checkout with a root `manifest.json`; resolve safe source symlinks into regular files and fail on broken/out-of-tree links.
- Add export validation and documentation for publishing the output as a dedicated Git repository, since Omarchy does not install a subdirectory from this monorepo.
- Keep the main repo authoritative. A later publishing step may automate synchronization to a companion repository; it must not depend on a personal access token being present in this implementation.
- Plugin updates update the user-space panel/exported QML. They do not automatically rewrite `/etc`, enroll faces, change PAM, or replace system packages.
- Uninstalling the panel disables/removes the user plugin only. A separate restore action/doc must use the existing module snapshot restore path for system changes.

## Security, Failure, and Recovery

- No camera startup during install or status refresh.
- No face scan without existing explicit user initiation.
- Plugin UI is not trusted as a root executable; privileged operations stay behind existing `sudo`/AUR prompts and existing installer validation.
- User cancellation, missing IR camera, missing AUR helper, incompatible Omarchy/plugin API, conflicting lock clone, failed enrollment, absent password PAM, or unsupported Quickshell must be shown in English/Chinese with a safe next step.
- Never enable a replacement lock clone unless the password PAM service exists and is readable, and do not disable the native lock before the new service is verified.
- Keep snapshots and restore instructions visible before system changes.

## Acceptance Criteria

- Exported plugin passes `omarchy plugin validate` on the supported Omarchy baseline and contains no symlinks.
- Export build fails clearly for broken symlinks and missing required assets.
- Bar-widget QML compiles and renders with Omarchy theme in English and Chinese; the widget itself opens the guided panel using the existing Omarchy widget/panel API.
- Environment checks are read-only and do not start camera capture, prompt for a password, or change files.
- Three authentication selections remain independent; sudo and Polkit are opt-in.
- Installer cancellation/failure cannot activate a lock clone without password fallback.
- Existing repository tests remain green, including installer/snapshot isolation and Quickshell loader regression.
- The Quickshell repair is available as a separate open PR for manual merge.

## Builder Decisions

- Use a setup-only plugin identity (for example `surface.face-setup`) rather than cloning the lock role at add time. The privileged install flow provisions `surface.lock` only after validation, avoiding an early lock-service takeover.
- Use one third-party `bar-widget` manifest with a colocated `Panel.qml` entry, following Omarchy's built-in menu/media widget pattern, rather than combining plugin kinds or relying on unsupported subdirectory discovery.
- Use a terminal window opened by the panel for existing interactive package review/enrollment, while hiding the long shell command from the user. Do not add a parallel privileged QML implementation in this first release.
- Package source and setup plugin export in the same repository first. Configure automatic cross-repository publication only after a companion repository and narrowly scoped credential are available.
