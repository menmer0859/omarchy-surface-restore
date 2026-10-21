# Face UI plugin 2.0 (development build)

This implements the approved HTML prototype as actual Qt Quick components using the existing Howdy/PAM authentication services. Source code is ready for review; this version has **not** been installed into the author's active shell or verified against a real camera in this development session.

## Omarchy integration

- User plugin clones, schemaVersion 1, service entry points, `keepLoaded` and `omarchy.clonedFrom` preserve Omarchy's authentication service lifecycle and capability boundaries. No changes to `/usr/share/omarchy`.
- Requires the installed shell's `Commons.Translations` API (available on the development host: Omarchy 4.5.0rc1, Quickshell 0.3.2.r7.g2b4501a-1). This is an API prerequisite, not a claim that all 4.x builds are compatible. Older 4.0.4 shells must update before installing this UI. Installers reject a missing API before mutation.
- Shared QML source lives in `assets/face-ui`; each deployed plugin receives its own regular files under `FaceUi/` and flat JSON catalogs in `i18n/`. Development symlinks are dereferenced by the resource deployer; no installed component depends on the repository remaining in place.
- No new lock engine, compositor patch, recognition model or authorization policy. Terminal sudo, graphical Polkit and screen unlock remain distinct PAM consumers.

## Languages and settings

Use **Omarchy menu → Setup → Language**. Select **English** or **简体中文**. The lock and graphical admin UI follow the global selection live through `Commons.Translations`; no separate language switch or shell restart is required. Missing translations fall back to English through the native API. Traditional Chinese and other catalogs are not yet provided.

The catalogs contain complete messages and `%1` placeholders. Omarchy's locale formats the clock/date, and RTL layout mirroring follows `Commons.I18n.rightToLeft` even when the text falls back to English. All plugin-owned labels are plain text. Application-provided Polkit messages and PAM diagnostics retain their upstream language; the plugin does not rewrite arbitrary authentication challenges.

Terminal consent reads the authenticating PAM user's `~/.config/omarchy/language` afresh for each request. It reads at most 64 bytes from a regular, non-symlink preference file; it never sources user configuration or runs a user translation script. An absent/unreadable preference falls back to the process locale and then English; an unsupported selected language falls back to English. The privileged helper intentionally uses the passwd home and standard `.config` location rather than trusting environment-provided file paths. Custom XDG config homes are therefore not supported for terminal language selection in this version. The root-owned helper/catalogs are installed alongside the sudo consent helper. The helper path is derived with shell builtins, never an inherited-PATH command. Isolated Python mode prevents user site packages/PYTHONPATH being loaded.

Only `y` or `Y` grants consent in either language. Enter, `n`, other text, EOF and the 30-second timeout return to the existing password path. The terminal displays a laptop-camera hint after consent; it cannot reliably identify which physical monitor contains a terminal, so it makes no left/right claim. The **Polkit PAM sentinel remains the exact English protocol string** `Use face authentication? [y/N]`; only its graphical presentation is translated.

Reduced motion follows `Commons.Style.reduceMotion` / Omarchy's animation setting. There is no separate plugin preference. The account portrait is the local `~/.face` image: if readable/decodable, a large round portrait appears above the name; otherwise the Omarchy logo appears beside it. There is no avatar editing UI on the lock screen. A selected Polkit administrator other than the session user never receives the session user's portrait.

## Interaction contract

1. Manual lock immediately secures the session and leaves face scanning unrequested. Key modifiers, releases and pointer motion on a lit screen do not count as face consent. A fresh ordinary key/press or **Use face** can request a scan on a lit lock screen.
2. After an observed display-off → wake edge or logind suspend → resume edge, settle for 1500ms, then request one face scan. No extra button is needed. Duplicate wake events do not rearm the timer. Monitor snapshots carry the lock and display-generation they sampled; late snapshots cannot manufacture a wake. A DPMS-off request is not treated as proof of an actual off state: monitor-driven auto recognition requires fresh off → on evidence. The one-second DPMS sampling can miss very brief off/on transitions; a deliberate fresh press or method choice remains available. A prior explicit password choice suppresses automatic face for the rest of that lock.
3. Each lock/attempt/wake has a generation. Relock, password selection, blank or suspend cancels pending work; old completions cannot unlock a later session. Failed recognition needs explicit retry or a new actual wake, never a background scanning loop.
4. Recognition UI is limited to 12 seconds. Switching to password, blanking or suspension aborts the PAM request. A closed lid is checked before starting lock face PAM. Keep the password path available at all times.
5. Graphical admin requests show the protected operation and selected administrator, with explicit face/password choices. Enter defaults to password, Escape/cancel cancels the request. Identity cycling still uses Polkit's allowed identities. Unrecognized challenges remain visible as plain text; the UI does not silently interpret them as face consent. **Once graphical face/fingerprint authentication is already running, the retained Polkit backend cannot switch that same conversation to password. The unavailable password action is hidden; Cancel/Escape ends the original authorization. After a failed face attempt, the password prompt becomes available.** This is a documented limitation from the HTML prototype, not an in-place switch claim.
6. On an external output, guidance points users to the laptop's upper screen bezel. Display names are only a heuristic for built-in vs external; no physical left/right relationship or face-position telemetry is invented.
7. Face/password buttons share the smiling scan and nine-dot icons. Status is not styled as a button. Timeout uses amber/clock; password error uses red and a single 340ms shake. Camera target pulses only three times, and reduced motion disables it. Successful PAM immediately unlocks/authorizes; no artificial delay or fake success animation gates the operation.

### Existing backend limitation

The Howdy PAM module spawns a separate matcher. Aborting the PAM conversation does **not yet prove that its matcher descendants relinquish the camera immediately**. The UI therefore reports request state, not a verified physical camera-off state. The 12-second UI timer must not be presented as a verified hardware power bound. Resolving matcher process ownership is a separate backend task; this UI release does not claim Windows Hello-equivalent spoof resistance or camera cancellation guarantees.

The Surface service also retains the earlier fingerprint implementation and static wallpaper behavior; the newest stock Omarchy lock has additional fingerprint/video-wallpaper handling that this plugin does not yet inherit.

## Install / upgrade

For an existing working Surface setup, first inspect targets:

```bash
./scripts/install-plugin-ui.sh --check
```

While the desktop is **unlocked**, close other authentication dialogs, keep a terminal open, and update the QML plugins:

```bash
./install.sh plugin-ui
omarchy restart shell
```

This discovers the existing Surface lock/Polkit clones (including the previous `eclipse.lock` / `eclipse.polkit` names), refuses ambiguous/unmanaged clones and symlink resource destinations, backs up full directories, and records new resources for restore. The UI-only upgrade does **not** change PAM, Howdy configuration or the terminal helper. To add terminal language support as well, run the existing consent installer after reviewing its prompt:

```bash
./install.sh sudo-face
```

For first-time installations, `./install.sh face` and `./install.sh polkit-face` now include these UI resources. They keep their existing explicit system-change prompts and prerequisites. The Polkit installer still handles the existing registration/device-access prerequisites.

Rollback uses `./scripts/restore.sh`: select the snapshot corresponding to the UI upgrade, then restart the shell from an unlocked desktop. If sudo localization was installed separately, it has its own snapshot. Keep the working terminal open until both password and face paths have been tested. Restore does not downgrade Omarchy packages.

## Verification

```bash
bash tests/run.sh
bash tests/compile-services.sh
```

The suite exercises the actual JS policy, PAM/configuration helpers, PTY consent and timeouts, resource deployment, and real QML views in an isolated offscreen shell. On an Omarchy host, it also checks live English → Chinese → English fallback, local-avatar fallback and portrait layout, literal markup-shaped identities, emitted method choices, and complete translated resource installation. `compile-services.sh` needs the session Wayland socket but only compiles the real lock/Polkit types; it does not instantiate them or create a PAM conversation. Automated tests deliberately do not unlock or take over the user's session.

Manual acceptance after installation (not performed during source development):

| Scenario | Expected result |
|---|---|
| Manual lock, face already in front of camera | Remains locked; no face attempt |
| Wait for screen off, wake with key/mouse | ~1.5s delay then exactly one scan |
| Failed face; wait several minutes | No periodic camera reactivation |
| Select password during wake delay | Timer cancelled; password works |
| Wrong password and retry | One short shake; field editable immediately |
| Suspend/close lid during scanning | Session stays locked; closed lid blocks a new lock-face request |
| Reopen/resume | One delayed scan when face mode is still selected |
| Second display | Real laptop-camera hint; no fake camera on the external screen |
| Chinese/English switched in Omarchy | Both graphical UIs update; next sudo consent uses selected language |
| Polkit choose password, face, other administrator, cancel | Correct allowed identity; explicit consent; fallback; action cancelled on cancel |
| `sudo -k -v`, `n`, then `y` in separate requests | Password fallback first; face only after `y` |
| Camera missing/busy/failed | No auto retry loop; password continues to work |
| Reduced motion, Tab/Enter/Escape, Caps Lock | Readable states, accessible choices, password warning |
| Install/restore plugin UI | Previous working plugin and all newly created resource paths restored/removed |
