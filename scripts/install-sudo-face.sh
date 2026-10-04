#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$root/scripts/common.sh"
require_commands sudo python3 install grep stat

sudo_pam=/etc/pam.d/sudo
system_auth=/etc/pam.d/system-auth
helper=/usr/local/libexec/omarchy-sudo-face-consent
model="/etc/howdy/models/${USER:?USER must name the enrolling account}.dat"

command -v howdy >/dev/null 2>&1 || die 'Howdy is not installed. Run ./install.sh face and enroll a model first.'
[[ -s "$model" ]] || die "No Howdy model found for $USER at $model. Enroll a model before enabling sudo face auth."
[[ -r /usr/lib/security/pam_howdy.so ]] || die 'The pam_howdy.so module is missing at /usr/lib/security/pam_howdy.so.'
[[ -r /usr/lib/security/pam_exec.so ]] || die 'The pam_exec.so module is missing at /usr/lib/security/pam_exec.so.'
[[ -r /usr/lib/security/pam_faillock.so ]] || die 'The pam_faillock.so module is missing at /usr/lib/security/pam_faillock.so.'
[[ -r "$sudo_pam" && -r "$system_auth" ]] || die 'Expected readable /etc/pam.d/sudo and /etc/pam.d/system-auth files.'
[[ ! -L "$helper" ]] || die "Refusing to replace symlink helper path: $helper"

# Validate the existing stack before asking for changes or creating a backup.
sudo python3 "$root/scripts/configure-sudo-pam.py" "$sudo_pam" "$system_auth" --check >/dev/null

printf 'This optional setup will ask for [y/N] before each sudo face attempt.\n'
printf 'Declining, timing out, or failed recognition continues to password authentication.\n'
printf 'Only %s and %s will be changed.\n\n' "$sudo_pam" "$helper"
ask_yes_no 'Enable consent-gated face authentication for sudo?' || die 'Stopped before making changes.'

sudo -v
backup_and_report "$sudo_pam"
if [[ -e "$helper" ]]; then
  backup_and_report "$helper"
else
  mark_new_path "$helper"
fi

sudo install -D -o root -g root -m 0755 "$root/scripts/sudo-face-consent" "$helper"
sudo python3 "$root/scripts/configure-sudo-pam.py" "$sudo_pam" "$system_auth"

[[ $(sudo stat -c '%U:%G:%a' "$helper") == root:root:755 ]] || die 'The consent helper is not root-owned mode 0755.'
sudo grep -qF "$helper" "$sudo_pam" || die 'The sudo PAM file was not updated as expected.'
info 'Consent-gated sudo face authentication is enabled.'
printf 'Keep this terminal open. Test once with N (password fallback), then in a separate terminal before closing this session.\n'
