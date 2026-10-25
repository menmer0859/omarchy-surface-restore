#!/usr/bin/env bash
set -euo pipefail

module_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
root=$(cd "$module_root/../.." && pwd)
source "$root/lib/common.sh"
require_omarchy
require_face_ui_api
require_commands sudo python3

user=${USER:?USER must name the enrolling account}
model="/etc/howdy/models/$user.dat"
pam_file=/etc/pam.d/omarchy-lock-face

command -v howdy >/dev/null 2>&1 || die 'Howdy is not installed. Configure the base face service first.'
[[ -s "$model" ]] || die "Howdy model is missing for $user; run the base face setup and enroll a model first."
[[ -s /etc/pam.d/omarchy-lock-password ]] || die 'The Omarchy lock password PAM service is missing; refusing to install face lock without password fallback.'

if [[ -e "$pam_file" ]]; then
  backup_and_report "$pam_file"
else
  mark_new_path "$pam_file"
fi
cat <<'PAM' | sudo tee "$pam_file" >/dev/null
#%PAM-1.0
auth       sufficient  pam_howdy.so
auth       required    pam_deny.so
account    include     system-local-login
PAM
sudo chmod 0644 "$pam_file"

"$module_root/scripts/install-lock-ui.sh"

info 'Howdy face authentication and Omarchy lock-screen switching are configured.'
printf 'Password authentication remains available. Face recognition still follows the existing lock and wake interaction. The UI/PAM request aborts after 12 seconds; immediate Howdy matcher cleanup on PAM abort is not yet guaranteed.\n'
