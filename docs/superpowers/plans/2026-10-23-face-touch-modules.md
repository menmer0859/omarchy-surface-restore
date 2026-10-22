# Surface Face and Touch Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Each task should be completed and reviewed before continuing.

**Goal:** Split the existing single-repository Omarchy Surface restore project into independently installable face-auth and touchscreen modules while preserving current users' CLI, authentication setup, and rollback behavior.

**Architecture:** Keep a root compatibility CLI and public overview. Move feature-specific scripts, assets, Quickshell packaging, tests, and guides into `modules/face-auth` and `modules/touch`; put only genuinely shared backup, restore, and environment helpers under `lib/`. Existing root script paths remain small forwarding wrappers, and existing snapshots remain readable.

**Tech Stack:** Bash, Python 3, QML/Qt Quick, JavaScript policy modules, C/PAM helper, PKGBUILD, JSON translation catalogs, existing Python/shell/Node/offscreen QML/native test harnesses.

**Spec:** `docs/superpowers/specs/2026-10-23-face-touch-modules-design.md`

## Global Constraints

- Face installation does not install `linux-surface`, `linux-surface-headers`, `iptsd`, or edit the linux-surface repository.
- Touch installation does not configure PAM, Howdy, face models, lock/Polkit plugins, or Quickshell face UI.
- Keep root CLI commands `touch`, `face`, `sudo-face`, `polkit-face`, `plugin-ui`, `check`, and `all`; `all` keeps its existing touch + initial face meaning.
- Keep lock-screen, terminal sudo, and graphical Polkit opt-ins distinct; do not make the terminal or graphical camera start without explicit consent.
- Never commit face models, images, camera captures, secrets, backups, local build output, or binary package artifacts.
- Preserve `/var/backups/omarchy-surface-restore` historical snapshots and restore only files owned by the selected module.
- Preserve the pinned Quickshell source revision and patch hashes; detect runtime capability before exposing Polkit return-to-face.
- Preserve English and Simplified Chinese UI/terminal catalogs and accurately state that the tested hardware baseline is Surface Laptop 5.
- Do not make remote GitHub changes as part of implementation; stop at a reviewable local branch unless the user separately directs publication.

## Review Focus

- Installing face after touch or touch after face must not cross module boundaries; add isolated fixture assertions to both installer tasks.
- Root or legacy script calls from a different current working directory must resolve module assets reliably; pin this in wrapper tests.
- A legacy snapshot with preexisting shared PAM files must be restored without deleting them; pin old and new snapshot layouts in restore tests.
- Plugin upgrade must find existing user-named Omarchy clones, preserve models/PAM, and reject ambiguous clones or symlink destinations; retain/extend current installer tests.
- New module paths must resolve Quickshell patch inputs and compile/run current tests without relying on the repository remaining at its current absolute path; exercise relative checkout paths in the packaging task.

---

### Task 1: Capture legacy CLI contract and module isolation fixtures

**Files:**
- Modify: `tests/test-installer.sh`
- Create: `tests/fixtures/module-isolation/` fixture scripts or marker executables
- Modify: `tests/run.sh`

**Interfaces:**
- Consumes: current root `install.sh` command list.
- Produces: regression tests proving the old command meanings and that dispatch selects exactly one module entry.

- [x] Add assertions for all seven existing CLI forms, including unknown action and the legacy `all` definition.
- [x] Add isolated marker fixtures showing `face` never invokes the touch entry and `touch` never invokes face setup; avoid invoking real `pacman`, `sudo`, or camera tools.
- [x] Run the focused installer test and verify it fails if the dispatch points to the wrong module.
- [x] Keep the existing baseline test changes scoped to this fixture.

### Task 2: Extract shared helpers and create root compatibility dispatch

**Files:**
- Create: `lib/common.sh`
- Move/adapt: `scripts/common.sh` → `lib/common.sh`
- Keep: `scripts/restore.sh` as compatibility command, moving its implementation to `lib/restore.sh` only if callers can preserve the legacy entry
- Modify: `install.sh`
- Modify: `tests/test-common.sh`, `tests/test-installer.sh`, `tests/test_restore_created_paths.sh`

**Interfaces:**
- Consumes: module installation contract from the spec.
- Produces: root dispatcher invoking `modules/face-auth/install.sh` and `modules/touch/install.sh`; common helper path sourced by both modules.

- [x] Write the focused root-dispatch tests from Task 1 first and run them to see the expected failures.
- [x] Extract common checks, backup creation, snapshot manifest helpers into `lib/common.sh` without changing their on-disk snapshot format.
- [x] Keep `./scripts/restore.sh` executable and compatible; its implementation may dispatch to shared `lib/restore.sh` but must accept existing arguments and snapshots.
- [x] Update `install.sh` dispatch to call module entrypoints using absolute paths derived from the script location, independent of caller CWD.
- [x] Keep `all` exactly touch then initial face configuration; do not add sudo or Polkit without explicit separate user choice.
- [x] Run common, restore, and root CLI tests. Confirm an old-format fixture restores preexisting system files and removes only paths marked newly created.

### Task 3: Move the touchscreen feature into its standalone module

**Files:**
- Create: `modules/touch/install.sh`
- Move/adapt: `scripts/install-touch.sh` → `modules/touch/scripts/install-touch.sh` or equivalent self-contained module entry
- Create: `modules/touch/README.md`
- Create: `modules/touch/README.zh-CN.md`
- Create: `tests/touch/` and move/adapt touch-specific installer assertions from `tests/test-installer.sh`
- Modify: `tests/run.sh`

**Interfaces:**
- Consumes: shared `lib/common.sh` and root dispatcher contract.
- Produces: direct module entry and old `./install.sh touch` behavior.

- [x] Add a fake-command test for exact touch effects: verified signing key, repository change, kernel/headers/iptsd install; assert no face/PAM/Howdy/lock resources are touched.
- [x] Move/adapt the current signed-key verification and `pacman -Syu --needed linux-surface linux-surface-headers iptsd` flow. Retain user confirmations and package upgrade warning.
- [x] Use module-root/repository-root resolution so invoking the module from another CWD still loads common helpers.
- [x] Ensure legacy `./install.sh touch` delegates to this implementation once and prints the same recovery/reboot guidance.
- [x] Document only touchscreen dependencies, packages, reboot, Limine fallback, and module-specific recovery in both languages.
- [x] Run focused touch and root compatibility tests; inspect fake-command log to prove no face path executed.

### Task 4: Move all IR face-auth functionality into its standalone module

**Files:**
- Create: `modules/face-auth/install.sh`
- Move/adapt: `assets/face-ui/`, `assets/omarchy-lock/`, `assets/omarchy-polkit/` → `modules/face-auth/assets/`
- Move/adapt face installers/helpers/configurators to `modules/face-auth/scripts/`
- Move/adapt: `packaging/quickshell-polkit-restart/` → `modules/face-auth/packaging/quickshell-polkit-restart/`
- Preserve old root script entrypoints as wrappers: `scripts/install-face.sh`, `scripts/install-sudo-face.sh`, `scripts/install-polkit-face.sh`, `scripts/install-lock-ui.sh`, `scripts/install-plugin-ui.sh`, `scripts/sudo-face-consent`, `scripts/restore.sh`
- Modify: face tests and test fixtures under `tests/face-auth/`; update `tests/run.sh`

**Interfaces:**
- Consumes: shared `lib/common.sh`, module root, existing Omarchy, Howdy/PAM and Quickshell API.
- Produces: face module install/upgrade entry, all existing face CLI forwarding paths, same deployed plugin contents and PAM behavior.

- [x] Add fake-command regression checks proving face install does not invoke touch repo/key/package commands; keep sudo-face, polkit-face, and UI upgrade opt-in.
- [x] Move shared QML and both locale catalogs intact; preserve resource manifest versions and Omarchy clone metadata.
- [x] Update `deploy-face-ui.py` source-root discovery and callers so resources resolve inside the module and installed UI remains self-contained.
- [x] Adapt every face helper/configurator to resolve root, module root, assets, and common library robustly from any CWD; do not bake in `/home/eclipse` or user plugin names.
- [x] Preserve lock, sudo, and Polkit installers' preflight, explicit confirmation, root-owned helper modes, camera-node restriction, and backup behavior.
- [x] Move the current Quickshell recipe with both patches and hash declarations; update `PKGBUILD`, prepare verification, module README, native harness invocation and package tests for the new relative path. Keep the 0.3.1 recipe as clearly labeled legacy compatibility only.
- [x] Preserve root legacy scripts as executable argument-forwarding wrappers, not duplicated implementation. Direct calls with optional arguments and from another working directory must work.
- [x] Move/adapt face-specific tests (Howdy config/PAM, plugin deployment, consent, locale, Polkit device access/UI/native tests); update fixture root discovery.
- [x] Run focused face tests. Confirm no path in an installed plugin refers back into the checkout.

### Task 5: Make backups and restores module-aware without breaking prior snapshots

**Files:**
- Modify: `lib/common.sh`
- Modify: `lib/restore.sh` or `scripts/restore.sh`
- Modify: `tests/test_restore_created_paths.sh`
- Create: `tests/test_module_restore_isolation.py`

**Interfaces:**
- Consumes: module identifier (`face-auth` or `touch`) passed by installers and existing backup manifest format.
- Produces: module-scoped new backups/restores plus backward-compatible restore of legacy snapshots.

- [x] Fixture-test old combined/separate snapshots before changing restore behavior.
- [x] Add module ownership metadata to new snapshots while keeping their original absolute-path inventory.
- [x] Add selected-module restore filtering only where metadata is present; for legacy snapshots retain the current displayed file list and confirmation instead of guessing the owner.
- [x] Test preexisting, newly created, and shared paths; a face restore must not remove touch repo/kernel files, and a touch restore must not edit PAM/model/plugin files.
- [x] Test public restore command and old snapshot selection from the repository root and module directories.

### Task 6: Rebuild bilingual root and module documentation

**Files:**
- Modify: `README.md`, `README.zh-CN.md`
- Create: `modules/face-auth/README.md`, `modules/face-auth/README.zh-CN.md`
- Create: `modules/touch/README.md`, `modules/touch/README.zh-CN.md`
- Modify: `docs/plugin-development.md`, `docs/plugin-development-progress.md`, `docs/local-acceptance-fixes.md`, `docs/local-acceptance-fixes-plan.md`, `docs/agent-handoff-face-auth-modules-2026-10-23.md`
- Preserve/review: `docs/acceptance-issues.md`, `docs/manual-test-scenarios.md`, `docs/research/`, `docs/surface-family-research-brief.md`

**Interfaces:**
- Consumes: final module CLI, boundaries, tests, verified version/acceptance evidence.
- Produces: consistent bilingual selection guide and module-specific operating documentation.

- [x] Rewrite the root quick start around choosing face-auth, touch, or both; provide commands that exist after Task 2–4.
- [x] Document face setup, separate optional sudo/Polkit consent, plugin-only UI upgrade, versioned Quickshell requirement, password fallback, backup/restore and known matcher shutdown limits.
- [x] Document touch setup separately: signed repository key verification, system upgrade side effects, kernel fallback and reboot validation.
- [x] Reconcile old 4.0.4 historical references with the actual Surface Laptop 5 / Omarchy 4.5.0rc1 installed baseline. Keep model/support claims only where evidence exists.
- [x] Record user feedback as overall multi-round satisfaction; do not manufacture per-test pass records. Carry forward unresolved limitations and installation evidence.
- [x] Review research reports/CSV and local machine-specific logs before publication; preserve user research locally, publish only reviewed material.
- [x] Remove contradictory obsolete “not installed” lead statements while preserving chronology in progress history.
- [x] Verify every documented command and relative link resolves in the new tree; check English and Chinese installation paths independently.

### Task 7: Root integration checks, security-content review, and final diff

**Files:**
- Modify: `tests/run.sh`
- Modify: root integration tests as needed
- Review: all staged files and `.gitignore`

**Interfaces:**
- Consumes: both standalone modules and root compatibility entry.
- Produces: release-reviewable local branch and evidence summary; no remote mutation.

- [x] From a clean fixture and from the module checkout root, invoke `./install.sh check`, each old CLI action in stub mode, module direct usage, and `all`; prove exact dispatch and no real system changes.
- [x] Run all available existing unit, policy, installer/restore, PAM compile, offscreen QML, Quickshell native/package, and Wayland type compilation checks using the relocated paths.
- [x] Inspect staged diff for model/image/credential/backup/build artifacts and ensure both module READMEs match actual behavior.
- [x] Run `git diff --check` and review `git diff --stat`/`git diff --name-status` for accidental broad moves or missing files.
- [x] Update the progress and handoff documents with final branch/head, module commands, test output, and known limitations.
- [x] Stop with a reviewable local branch and summarize readiness. Do not push, open/modify a PR, or merge in this plan.

## Self-review

- Every target behavior maps to a task: root CLI/isolation (1–2, 7), touch module (3), face module and native packaging (4), independent rollback (5), bilingual instructions and evidence (6), moved-path regression (1–7).
- Historical upgrade and restore risk is tested before code movement (Tasks 1, 2, 5); no task replaces live PAM configuration.
- Main remaining risk is path depth and test fixture discovery after directory relocation; it is explicitly covered in Tasks 3, 4 and Review Focus.
- Publication, remote branch choice, PR, and merge are outside this implementation plan.
