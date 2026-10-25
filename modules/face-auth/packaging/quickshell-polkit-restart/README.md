# Polkit conversation restart for the current Omarchy Quickshell

This recipe pins the same source revision as Omarchy's installed
`0.3.2.r7.g2b4501a-1`, with local package release `3.1`. The older
`../quickshell-xdg-session` recipe remains a reference for Quickshell 0.3.1.

Release `2` omitted Omarchy's `load_qtquick_611.patch` and must not be used
with the Qt 6.12 Omarchy shell. Qt 6.12 adds a `QtQuick.Color` singleton
which shadows the shell's theme singleton in unqualified plugin imports,
leaving accent and role colors undefined. Release `3.1` retains the official
`OmarchyLoadPatch` behavior, including dynamically loaded external plugins,
in addition to this project's Polkit changes. This is an Omarchy distribution
patch on the same upstream source, rather than a different source fork.

The loader patch is vendored unchanged from
[omacom/omarchy-pkgs](https://github.com/omacom/omarchy-pkgs/blob/master/pkgbuilds/quickshell/load_qtquick_611.patch),
Git blob `660965b4907bcd67f8d810898c9db5f19d198917`, SHA-256
`23b65d205d825f11a1cd8501acbc6e50250d09a6ce607e2ff8b3cf5d438bd0ce`.

The package includes the XDG session lookup fix and a native
`AuthFlow.restartAuthentication()` method. That method only accepts a
conversation waiting for input. It keeps the original protected authorization
request, cookie and selected administrator, disconnects the old session before
cancelling it, clears stale conversation state and starts a replacement PAM
conversation. It rejects busy, completed and cancelled requests. Identity changes
use the same safe replacement path, avoiding a retry caused by synchronous old
session completion.

The graphical password view offers **Return to face** only when this native API
exists and the same request and administrator have already presented the managed
PAM face-consent prompt. Returning clears the entered password and reopens PAM's
method picker. A separate explicit **Use face** choice is required to start the
camera. An unpatched runtime retains password authentication and does not offer
an unsupported return action. Restart follows the installed PAM stack; any
fingerprint step in that stack still runs in its normal order.

Build normally from this directory with `makepkg`. This produces a local package;
it does not install it unless an explicit install option is supplied. The recipe
uses a pinned archive and checked patch hashes and does not alter PAM policy.

Before installation, run the native regression against the recipe's prepared
source from the repository root:

```sh
makepkg --dir modules/face-auth/packaging/quickshell-polkit-restart --nobuild
./modules/face-auth/tests/run-polkit-native.sh "$PWD/modules/face-auth/packaging/quickshell-polkit-restart/src/quickshell-2b4501a282689792b62e94f3fb30d8f512324fe6"
node modules/face-auth/tests/test_polkit_return.js
./modules/face-auth/tests/run-polkit-qml.sh
```

The native regression compiles the actual patched AuthFlow, Identity and
Retainable code, with only the external Polkit session and D-Bus reply boundaries
replaced. It checks request and identity preservation, cancellation reentrancy,
replacement count, conversation clearing and rejection after submission,
cancellation or success. It never connects to the live agent, PAM or camera.
The QML test renders only AuthorizationView using an isolated offscreen runtime.

After building, also test the actual candidate binary against the theme-name
collision. This creates only temporary QML objects, including an external
plugin; it does not start the real shell or authenticate:

```sh
bash modules/face-auth/tests/run-omarchy-load-compat.sh "$PWD/modules/face-auth/packaging/quickshell-polkit-restart/src/quickshell-2b4501a282689792b62e94f3fb30d8f512324fe6/build/src/quickshell"
```

On Qt 6.12, the broken release `2` fails with `OMARCHY_COLOR_COLLISION`;
the Omarchy-compatible build must print `OMARCHY_LOAD_COMPAT_PASS`.
