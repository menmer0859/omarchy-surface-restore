# Sudo Face Consent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in `sudo-face` setup that asks for explicit terminal consent before Howdy, keeps `pam_faillock` behavior, and falls back to the existing sudo password.

**Architecture:** A root-owned terminal-consent helper runs through `pam_exec.so`; a Python configurator builds the sudo-only PAM auth flow from the current `system-auth` faillock options. An installer backs up system files and installs the helper; the existing CLI exposes it as a separate action.

**Tech Stack:** Bash, Python 3 standard library, Linux-PAM, Howdy, existing shell/Python test suite, GitHub connector API.

**Spec:** `docs/superpowers/specs/2026-10-04-sudo-face-consent-design.md`

## Global Constraints

- Require explicit `y` or `Y` from `/dev/tty` before starting Howdy; default is decline.
- Limit changes to `/etc/pam.d/sudo` and the root-owned consent helper; leave `system-auth` and all other PAM services unchanged.
- Match preauth/authsucc arguments from `/etc/pam.d/system-auth`; fail without edits if the rules are missing or ambiguous.
- On refusal, missing TTY, or face failure, continue to the existing `system-auth` password chain.
- Back up overwritten paths under `/var/backups/omarchy-surface-restore/<timestamp>/`; record newly created helper paths for restore.
- Never copy or publish face models.
- Keep GitHub script executable modes (`100755`) intact.

## Review Focus

- Decline, Enter, EOF, or missing TTY must skip Howdy and reach password auth.
- Howdy failure must reach password auth; success must run faillock `authsucc` before returning success.
- A locked account must fail during preauth before the consent helper or camera runs.
- Missing/duplicate faillock rules or an unsupported sudo PAM layout must fail without changing files.
- Re-running the installer must not duplicate rules, and restore must recover the original sudo file and remove a newly installed helper.

---

### Task 1: PAM transformation and confirmation helper

**Files:**
- Create: `scripts/configure-sudo-pam.py`
- Create: `scripts/sudo-face-consent`
- Create: `tests/test_configure_sudo_pam.py`
- Create: `tests/test_sudo_face_consent.py`

**Interfaces:**
- `render_sudo_pam(sudo_config: str, system_auth: str) -> str` returns an idempotent sudo PAM configuration or raises `ValueError` without changing input files.
- `scripts/sudo-face-consent` reads/writes `/dev/tty`, accepts only `y`/`Y`, and exits nonzero on decline or no TTY.

- [x] Write tests for generated PAM jump order, preserved account/session/password include, idempotence, and missing/duplicate faillock or sudo rules.
- [x] Run the focused tests; verify they fail because the configurator does not exist.
- [x] Write a pseudo-terminal test for affirmative consent; assert negative/empty input and unavailable controlling TTY return nonzero.
- [x] Run the consent tests; verify they fail because the helper does not exist.
- [x] Implement the configurator and helper to pass these tests.
- [x] Run both focused test files and confirm the PAM order matches the spec.

### Task 2: Safe opt-in installer and CLI action

**Files:**
- Create: `scripts/install-sudo-face.sh`
- Modify: `install.sh`
- Modify: `tests/test-installer.sh`
- Modify: `tests/run.sh`

**Interfaces:**
- `./install.sh sudo-face` invokes the standalone sudo face installer; the interactive menu exposes the same optional action.
- The installer validates Howdy, model, PAM module, and faillock layout before mutation; it backs up `/etc/pam.d/sudo` and any replaced helper before installing, then records a new helper for restore.

- [x] Add installer smoke tests for `sudo-face` dispatch and help/menu output.
- [x] Run the smoke tests; verify they fail before the action exists.
- [x] Implement the installer using existing `common.sh` backup and restore markers; make it idempotent and keep all unrelated sudo/account/session lines intact.
- [x] Add the Python and pseudo-terminal test files to the full test runner.
- [x] Run `bash tests/run.sh` and verify all available checks pass.

### Task 3: User documentation and repository metadata

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `docs/verified-surface-laptop-5.md`

- [x] Document the optional `sudo-face` command, explicit `[y/N]` consent, password fallback, faillock protection, and restore behavior in both READMEs.
- [x] Update the verified device record without claiming unattended or default face auth.
- [x] Review wording against the spec and ensure no biometric data is included.
- [x] Run the full test suite and inspect `git diff --check` and `git ls-files --stage` for expected executable modes.

### Task 4: Apply locally and publish

**Files:**
- System target: `/etc/pam.d/sudo`
- System helper: `/usr/local/libexec/omarchy-sudo-face-consent`
- Backup root: `/var/backups/omarchy-surface-restore/<timestamp>/`

- [ ] Keep the current authenticated terminal open; inspect the exact planned backup and PAM diff.
- [ ] Run `./install.sh sudo-face` locally and confirm the backup exists, helper ownership/mode are root-owned `0755`, and only the intended sudo auth lines changed.
- [ ] In a fresh terminal, verify decline and no-TTY fall back to password; verify a deliberate `y` starts Howdy, failed recognition falls back, and face success authenticates.
- [ ] Run the full tests again after any corrections.
- [ ] Sync the complete verified tree to GitHub `main` using the authorized GitHub integration, preserving `100755` modes for executable scripts.
- [ ] Fetch the published commit/files and verify branch contents, tests, documentation, and executable modes.

**Commit messages:** `feat: add consent-gated sudo face auth`, `docs: explain sudo face consent`.
