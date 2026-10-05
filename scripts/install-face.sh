#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$root/scripts/common.sh"
require_omarchy
require_surface_hint
require_commands pacman sudo python3 find sort id

[[ -d /dev/v4l/by-path ]] || die 'No stable V4L2 camera paths found. Check camera permissions and install v4l-utils.'
require_commands v4l2-ctl
mapfile -t cameras < <(find /dev/v4l/by-path -maxdepth 1 -type l -print | sort)
((${#cameras[@]} > 0)) || die 'No /dev/v4l/by-path camera nodes were found.'

if pacman -Q omarchy 2>/dev/null | grep -qE ' 4\.0\.4-[^ ]+$'; then
  info 'Omarchy 4.0.4 detected (the lock-screen integration has been tested on this version).'
else
  warn 'The included Omarchy lock-screen integration was tested on Omarchy 4.0.4.'
  ask_yes_no 'Continue on this Omarchy version?' || die 'Stopped before making changes.'
fi

printf 'Camera paths (identify the IR camera by testing one at a time):\n'
for index in "${!cameras[@]}"; do
  printf '  %d) %s\n' "$((index + 1))" "${cameras[$index]}"
done
read -r -p 'IR camera number: ' camera_number
[[ "$camera_number" =~ ^[0-9]+$ ]] || die 'Enter a camera number from the list.'
((camera_number >= 1 && camera_number <= ${#cameras[@]})) || die 'Camera number is outside the list.'
camera_path=${cameras[$((camera_number - 1))]}
[[ -c "$camera_path" ]] || die "Selected path is not a video device: $camera_path"
v4l2-ctl --device "$camera_path" --all >/dev/null 2>&1 || die 'The current user cannot query that camera. Check the video/input groups and choose an accessible IR device.'

helper=''
if command -v paru >/dev/null 2>&1; then helper=paru; fi
if command -v yay >/dev/null 2>&1; then helper=yay; fi
[[ -n "$helper" ]] || die 'Install an AUR helper (yay or paru), review the Howdy PKGBUILD, then rerun this script.'

printf '\nSelected device: %s\n' "$camera_path"
printf 'The AUR helper will install howdy-git and ask before package changes.\n'
printf 'You will enroll your face locally; the model will not be copied into this project.\n'
ask_yes_no 'Proceed?' || die 'Stopped before making changes.'

howdy_config_existed=false
if [[ -f /etc/howdy/config.ini ]]; then
  backup_and_report /etc/howdy/config.ini
  howdy_config_existed=true
fi
howdy_models_existed=false
if [[ -d /etc/howdy/models ]]; then
  backup_and_report /etc/howdy/models
  howdy_models_existed=true
fi
sudo -v
"$helper" -S --needed howdy-git
command -v howdy >/dev/null 2>&1 || die 'The package installed but the howdy command is missing.'
[[ -f /etc/howdy/config.ini ]] || die 'Expected /etc/howdy/config.ini after Howdy installation.'
if [[ "$howdy_config_existed" != true ]]; then
  mark_new_path /etc/howdy/config.ini
fi
if [[ "$howdy_models_existed" != true && -d /etc/howdy/models ]]; then
  mark_new_path /etc/howdy/models
fi
sudo python3 "$root/scripts/configure-howdy.py" /etc/howdy/config.ini "$camera_path"

printf '\nEnroll a face for user %s. Follow the camera prompts; this stays in /etc/howdy/models.\n' "$USER"
model_file="/etc/howdy/models/$USER.dat"
if [[ ! -e "$model_file" ]]; then
  mark_new_path "$model_file"
else
  backup_and_report "$model_file"
fi
sudo howdy -U "$USER" add

[[ -s "$model_file" ]] || die "Howdy did not create a model at $model_file."
user_group=$(id -gn "$USER")
sudo chown root:root /etc/howdy/models
sudo chmod 0711 /etc/howdy/models
sudo chown "root:$user_group" "$model_file"
sudo chmod 0640 "$model_file"
sudo -u "$USER" test -r "$model_file" || die "The current user cannot read the Howdy model: $model_file"

pam_file=/etc/pam.d/omarchy-lock-face
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

"$root/scripts/install-lock-ui.sh"

info 'Howdy face authentication and Omarchy lock-screen switching are configured.'
printf 'After the secure lock appears, press a key or click/touch to request one face scan (up to 12 seconds). Retry is explicit; password remains available and its PAM service is unchanged.\n'
