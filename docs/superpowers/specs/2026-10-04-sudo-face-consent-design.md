# Sudo face authentication with explicit consent

## Goal and scope

Let a user deliberately choose Howdy face authentication for an interactive local `sudo` request on Omarchy. The camera must not start merely because a user is in front of the laptop. If the user declines, has no controlling terminal, or face recognition fails, the existing password authentication remains available. The setup is opt-in and limited to the `sudo` PAM service.

Do not modify the global `system-auth` stack, lock-screen behavior, desktop login, `su`, or other PAM services. Do not make face recognition run by default.

## User experience

When sudo needs authentication, show a terminal prompt such as `Use face authentication? [y/N]`. Only an explicit `y`/`Y` starts Howdy. Enter, any other answer, EOF, or an unavailable controlling terminal skips face recognition and continues to the normal password prompt. If Howdy does not authenticate, sudo also continues to the password prompt.

This is the terminal equivalent of a deliberate confirmation gesture. No graphical dialog or hardware-button binding is included.

## Authentication design

Add an explicit `sudo-face` installer action. It installs a root-owned confirmation helper and edits only `/etc/pam.d/sudo`; it backs up both existing paths first and is idempotent. The existing `sudo` password include and account/session rules remain in place.

The sudo auth flow will use a root-owned confirmation helper called by `pam_exec.so`. The helper reads and writes only `/dev/tty`, accepts only `y` or `Y`, and returns failure on every other input or when no controlling terminal is available. PAM's environment is treated as untrusted; the helper uses fixed paths and does not interpolate PAM environment values into commands.

The generated auth flow will follow this order (the faillock options are copied from the matching lines in `system-auth`):

```pam
auth requisite pam_faillock.so preauth <existing-preauth-options>
auth [success=ok default=2] pam_exec.so /usr/local/libexec/omarchy-sudo-face-consent
auth [success=ok default=1] pam_howdy.so
auth [success=done default=die] pam_faillock.so authsucc <existing-authsucc-options>
auth include system-auth
```

The PAM jump counts are intentional: declining skips Howdy and `authsucc`; a Howdy failure skips only `authsucc` and reaches the regular password chain; Howdy success runs `authsucc` and then completes authentication. The pre-authentication `requisite` rule rejects locked accounts before asking for consent or opening the camera.

The sudo auth flow will:

1. Apply a `pam_faillock` pre-authentication check using the options already configured in `/etc/pam.d/system-auth`. A locked account must not reach the face check.
2. Ask for explicit terminal consent. A decline or inability to ask skips both Howdy and face-success bookkeeping, then continues to `system-auth`.
3. Run `pam_howdy.so` only after consent. A failed or unavailable face check continues to `system-auth`.
4. On face success, run `pam_faillock.so authsucc` with the existing `system-auth` options before completing authentication. A failure in this success bookkeeping fails closed.

If the required `pam_faillock` rules or Howdy PAM module cannot be found, the installer must stop without changing either system file and explain what is missing. Do not guess at PAM rule placement.

## Project and local changes

The repository will gain a separate sudo-face installer/configuration helper, unit and shell tests for confirmation behavior, PAM rule ordering, password fallback, idempotence, refusal when rules are unsupported, and backup behavior, plus updated English and Chinese README instructions. Existing scripts keep their executable file modes in the published GitHub tree.

On this Surface, the confirmed action will make a backup under the existing project backup root, then apply and inspect the resulting `/etc/pam.d/sudo` and helper permissions. Do not enroll, export, or publish any biometric model.

## Verification and recovery

Run the full project test suite, syntax checks, and a non-authenticating PAM configuration/order check before claiming completion. Then verify in a fresh terminal that declining reaches the password prompt. Separately test accepting the prompt and confirming that Howdy starts; confirm unsuccessful recognition returns to the password prompt. Keep an existing authenticated terminal open until the new sudo stack has been verified. The project's restore command must restore the saved sudo file and remove a newly installed helper when applicable.

Real camera behavior cannot be proven by repository tests; it must be verified interactively on this device.
