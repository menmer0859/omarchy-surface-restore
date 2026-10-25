# Omarchy Face Setup Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an installable Omarchy setup plugin that guides users through read-only readiness checks and launches the existing face-auth installation flow for independently selected lock, sudo, and Polkit integrations.

**Architecture:** Keep `omarchy-surface-restore` as the source of truth. Export a regular-file plugin root with a setup bar widget and bundled backend; validate it with Omarchy's validator. The setup UI launches the existing interactive installers in a terminal only after user selection, and the lock clone remains provisioned by the current installer after PAM/model prerequisites succeed.

**Tech Stack:** Bash, Python 3 standard library, Qt/QML/Quickshell, Omarchy plugin manifest v1, existing Node/Python/shell test runners.

**Spec:** `docs/superpowers/specs/2026-10-25-omarchy-face-setup-wizard-design.md`

## Global Constraints

- Do not start camera capture from plugin add, status checks, or panel refresh.
- Keep password authentication configured and usable as fallback.
- Lock, terminal sudo, and graphical Polkit are separate choices; sudo and Polkit are opt-in.
- Never enable/activate a lock clone before password PAM, Howdy model, and selected readiness checks succeed.
- Export a plugin root with regular files only; reject broken/out-of-tree symlinks and missing required resources.
- Use existing snapshot/restore installers for privileged changes; plugin update/removal does not modify `/etc`.
- Include English and Simplified Chinese strings, following current Omarchy translation/theme APIs.
- Keep the touch module and existing installer CLI behavior independent and compatible.
- Verify initial compatibility on Surface Laptop 5 with Omarchy 4.5.0rc1; report other combinations as unverified.

## Review Focus

- A failed/canceled selected installer must not mark auth ready or switch the lock clone; test canceled/failed orchestrator results.
- Missing lock password PAM or model must keep the native lock active; test the final readiness gate.
- External plugin code must not run privileged actions during `omarchy plugin add` or status refresh; test command-plan generation and status read-only behavior.
- Plugin export must materialize source symlinks without escaping the repository; test normal links, broken links, and out-of-tree targets.
- A third-party clone with another ID can still conflict with `omarchy.lock`; test setup preflight conflict reporting.

---

### Task 1: Build a deterministic plugin export

**Files:**
- Create: `modules/face-auth/scripts/export-setup-plugin.py`
- Create: `modules/face-auth/tests/test_setup_plugin_export.py`
- Modify: `tests/run.sh`
- Create: `modules/face-auth/assets/face-setup/manifest.json`
- Create: `modules/face-auth/assets/face-setup/SetupBarWidget.qml`
- Create: `modules/face-auth/assets/face-setup/i18n/en.json`
- Create: `modules/face-auth/assets/face-setup/i18n/zh-CN.json`

**Interfaces:**
- Exporter CLI: `python3 modules/face-auth/scripts/export-setup-plugin.py --output DIR`.
- Produces a root-level `manifest.json` for `surface.face-setup` and copies the panel, translations, setup status/backend files, shared `lib/`, and required face-auth installers/resources into a self-contained directory.

- [ ] **Step 1: Write failing export tests** for root manifest and required files, deterministic output, no symlinks, and failure on broken/out-of-tree source links.
- [ ] **Step 2: Run** `python3 -m unittest modules.face-auth.tests.test_setup_plugin_export -v`; confirm failures come from the missing exporter.
- [ ] **Step 3: Implement** a staged export map and safe symlink materialization with repository-root containment checks.
- [ ] **Step 4: Run** the exporter tests and `omarchy plugin validate <temp-export>`; expected successful plugin validation with no symlinks.
- [ ] **Step 5: Commit** `feat: export self-contained Omarchy face setup plugin`.

### Task 2: Add read-only setup readiness backend

**Files:**
- Create: `modules/face-auth/scripts/face-setup-status.py`
- Create: `modules/face-auth/tests/test_face_setup_status.py`
- Modify: `tests/run.sh`

**Interfaces:**
- CLI: `python3 face-setup-status.py --json`, returning stable JSON fields for Omarchy/plugin API, camera paths/access, Howdy/model, lock PAM/fallback PAM, lock-clone conflicts, sudo PAM/helper, Polkit PAM/agent/device access, and Quickshell restart capability.
- Detect-only mode may inspect V4L2 nodes and `v4l2-ctl`; it must never open the camera stream or write files.

- [ ] **Step 1: Write failing tests** with injected filesystem/command roots for ready, partially configured, missing camera, and competing lock clone states.
- [ ] **Step 2: Run** the focused unittest module and confirm missing backend failures.
- [ ] **Step 3: Implement** a standard-library status collector with testable path/command injection and no mutation calls.
- [ ] **Step 4: Run** focused tests and manually invoke `--json`; verify valid JSON and no credential/camera prompt.
- [ ] **Step 5: Commit** `feat: inspect face authentication setup readiness`.

### Task 3: Add bilingual Omarchy setup bar widget

**Files:**
- Create: `modules/face-auth/assets/face-setup/Panel.qml` (one bar-widget entry that renders its icon and setup overlay)
- Create: `modules/face-auth/assets/face-setup/SetupModel.js`
- Create/modify: `modules/face-auth/assets/face-setup/i18n/en.json`
- Create/modify: `modules/face-auth/assets/face-setup/i18n/zh-CN.json`
- Modify: `tests/run.sh`
- Modify: plugin-export tests from Task 1 to require all UI resources.

**Interfaces:**
- Manifest plugin ID `surface.face-setup`, kind `bar-widget`, localized `displayName`/description, and `entryPoints.barWidget: "Panel.qml"`.
- Follow the installed Omarchy menu/media pattern: the bar widget owns and summons its setup overlay; do not use combined kinds or subdirectory manifests.
- Widget requests status JSON through `Quickshell.Io.Process`, renders overall readiness, and displays independent lock/sudo/Polkit checkboxes (sudo and Polkit unchecked by default).
- UI provides explicit “Check” and “Configure selected features” actions, states that passwords remain available, and has no camera-open code.

- [ ] **Step 1: Add QML contract tests** asserting required states and three independent opt-in controls exist in both locales.
- [ ] **Step 2: Run** QML syntax/contract tests and verify the absent component/manifest behavior fails.
- [ ] **Step 3: Implement** a theme-aware, accessible setup panel using current Omarchy UI components and translation API.
- [ ] **Step 4: Run** `qmlformat`, the Omarchy plugin validator, translation parity tests, and the existing offscreen Quickshell suite. The suite has no `PanelWindow` backend, so actual panel rendering remains part of local desktop acceptance.
- [ ] **Step 5: Commit** `feat: add bilingual face setup panel`.

### Task 4: Launch the selected existing install flows safely

**Files:**
- Create: `modules/face-auth/scripts/run-face-setup.sh`
- Create: `modules/face-auth/scripts/install-howdy-base.sh`
- Create: `modules/face-auth/scripts/install-lock-face.sh`
- Modify: `modules/face-auth/scripts/install-face.sh`
- Modify: `modules/face-auth/assets/face-setup/Panel.qml`
- Create: `modules/face-auth/tests/test_run_face_setup.sh`
- Modify: `tests/run.sh`

**Interfaces:**
- Backend accepts explicit flags `--lock`, `--sudo`, `--polkit`; it rejects no selections and requires an accessible camera before any selected flow.
- UI invokes `omarchy-launch terminal` with a fixed argument vector and the setup script from its own plugin checkout; it does not interpolate user-controlled text into shell code.
- Run the camera/Howdy/model status check first. If Howdy is not ready, run the base-only installer, which enrolls Howdy but does not write any authentication PAM service. Then run only selected lock, sudo, and Polkit installers in that order. Stop on first non-zero exit; do not run later steps after failure.

- [x] **Step 1: Write failing shell tests** for no-selection rejection, explicit selection order, stopping after failure, and no privileged work on status-only action.
- [x] **Step 2: Run** `bash modules/face-auth/tests/test_run_face_setup.sh`; confirm intended failures.
- [x] **Step 3: Implement** an argument-vector based terminal launcher and selected installer orchestrator that calls existing module entry points.
- [x] **Step 4: Run** shell tests plus installer tests; validate cancellation and error paths leave later integrations untouched.
- [x] **Step 5: Commit** `feat: run selected face setup installers from Omarchy panel`.

### Task 5: Document distribution and publish readiness

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `modules/face-auth/README.md`
- Modify: `modules/face-auth/README.zh-CN.md`
- Modify: `docs/plugin-development.md`
- Create: `docs/face-setup-plugin-distribution.md`
- Modify: `.github/workflows/` only if an existing CI workflow can validate export without cross-repository credentials.

- [x] **Step 1: Add documentation checks** for export instructions and explicit warning that no official marketplace listing is created.
- [x] **Step 2: Run** docs grep/checks and verify failure before adding the distribution guide.
- [x] **Step 3: Document** how to generate and validate the plugin export, install the published Git URL, use the setup panel, update, and restore system snapshots; distinguish local export validation from publication.
- [x] **Step 4: Run** all project tests: `bash tests/run.sh` and validate exported plugin on this Omarchy host. `compile-services.sh` was also attempted but requires the session Wayland socket, which this sandbox cannot access.
- [x] **Step 5: Commit** `docs: explain Omarchy face setup plugin distribution`.

### Task 6: Review the complete branch and prepare the user-facing PR

**Files:**
- Review all changed files and generated plugin export.

- [ ] **Step 1: Run** full test suite and inspect `git diff --check` and plugin export tree for symlinks/secrets.
- [ ] **Step 2: Confirm** the Quickshell repair remains isolated in PR #4 and no changes target `main` directly.
- [ ] **Step 3: Push** the setup-plugin work on its own branch and create a draft/open PR targeting the repair branch so the repair stays a separate PR.
- [ ] **Step 4: Attach** the PR to the task and report manual Omarchy acceptance steps.
