# Face authentication plugin implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this approved design task-by-task.

**Goal:** Implement the approved lock/admin UI as user-owned Omarchy plugins with live English and Simplified Chinese translations.
**Architecture:** Retain WlSessionLock, Howdy PAM and PolkitAgent. Share local QML identity, icon, action, guidance and password components between the two plugins. Use Commons.Translations catalogs and Omarchy's selected language; no second language setting. Terminal consent reads the selected user's language safely and preserves explicit y/N semantics.
**Tech Stack:** Qt Quick, Quickshell, JavaScript policy, Python/Bash installers, QtTest.
**Spec:** Approved prototype at ../../../../face-unlock-prototype/README.md, plus this conversation's bilingual requirement.

## Global constraints
- Do not install into the running shell or change PAM during development.
- Do not modify /usr/share/omarchy. Keep schemaVersion 1, service entryPoints, authentication capability, clonedFrom and keepLoaded.
- Manual lock: no scan. Actual screen wake/resume: 1500ms settle then one scan. Failed/expired attempts need explicit retry. No unattended scan loop.
- Administrative authentication always requires explicit consent; Enter defaults to password.
- Plugin-owned text is plain text, complete translatable messages, locale-aware dates/numbers and live bindings. English fallback for other locales.
- No invented face-position telemetry, no fake camera-on/off assertion, no new biometric backend.

## Review focus
- Stale face results/timers after mode change, re-lock, blank or suspend must not unlock.
- Translated labels must not change the Polkit PAM consent protocol.
- Untrusted identity/message strings render plain; another selected identity must never display the session user's portrait.
- Terminal language selection must never execute user-controlled files or trust environment paths as privileged code.
- Upgrade/restore must include components/catalogs and refuse conflicting auth plugins before changes.

### Task 1: Shared UI and i18n
Files: assets/face-ui/*, assets/omarchy-lock/LockView.qml, assets/omarchy-polkit/AuthorizationView.qml, assets/omarchy-polkit/PolkitAgent.qml, tests/qml/*, tests/run-qml.sh.
Interfaces: shared AuthStrings (Commons.Translations), Identity { userName, displayName, avatarPath }, Action { label, iconName, clicked }, PasswordField { text, submit, editing }, CameraHint { externalDisplay, scanning }.
- [x] Write QtTest cases for live en/zh-CN/English fallback, identity fallback, plain-text markup, password submit and choice signals. Observe failure before implementation.
- [x] Implement local SVG icons, plain text components, identity, camera hint, accessible buttons, password show/hide/Caps Lock, reduced motion and distinct feedback.
- [x] Connect view signals to existing lock/Polkit logic, keeping identity choice and cancellation.
- [x] Run QtTest and existing suite; commit.

### Task 2: Wake policy integration
Files: assets/omarchy-lock/FaceAttemptPolicy.js, assets/omarchy-lock/Service.qml, tests/test_lock_face_policy.js, QtTest lock view cases.
Interfaces: transition(state,event) returns state/effects; WAKE_DELAY_ELAPSED tokens include lockId and wakeId. DISPLAY_BLANKED cancels delay/scan; SUSPEND cancels; RESUME can schedule one fresh delay.
- [x] Test manual lock without scan, blank+wake delayed single attempt, duplicate wake, explicit password suppression, stale delay/results, suspend/resume, failure no retry. Observe failing behavior.
- [x] Implement policy effects and QML timer wiring; preserve secure-lock gate and password fallback.
- [x] Run policy/QtTest/full suite; commit.

### Task 3: Terminal localization and packaging
Files: scripts/sudo-face-consent, scripts/install-*.sh, scripts/deploy-face-ui.py, tests/test_sudo_face_consent.py, tests/test_deploy_face_ui.py, README*.md, docs/plugin-development.md.
- [x] Add behavioral tests for catalog deployment/upgrade and Chinese consent on a real PTY; decline/timeout continue to fail closed. Observe failure.
- [x] Install shared components and root i18n catalogs for each plugin; check Commons.Translations prerequisite before mutation. Read only a bounded language code via the PAM user's passwd home with safe file opening; never source files. Keep Polkit sentinel English.
- [x] Document setup language, avatar location, preview/installation/rollback, backend limitations and manual acceptance matrix.
- [x] Run full suite and offscreen real-QML load, prepare independent review of the branch; fix material findings with regression tests. Preserve code for review; no live auth deployment yet.
