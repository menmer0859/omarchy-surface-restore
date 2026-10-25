# Omarchy Face Setup Plugin Distribution

## What is implemented

The source repository contains the `surface.face-setup` bar-widget plugin under `modules/face-auth/assets/face-setup`. Its panel is bilingual (English and Simplified Chinese), performs read-only readiness checks, and lets the user opt into lock-screen, terminal sudo, and graphical Polkit setup independently. Privileged changes only start after the user selects features and confirms the existing installer prompts.

The exporter creates a standalone plugin checkout with a root-level manifest and regular files only:

```bash
python3 modules/face-auth/scripts/export-setup-plugin.py --output /tmp/surface-face-setup
omarchy plugin validate /tmp/surface-face-setup
```

The generated output directory must be empty or new and outside the source repository. Do not commit device face models, backups, credentials, or local package artifacts into the plugin repository.

## Current publishing status

The source repository is **not** a direct `omarchy plugin add` target: Omarchy clones a Git repository and expects `manifest.json` at that repository's root. This change implements and validates the export, but it does not create a companion GitHub repository or submit a plugin-catalog listing. The plugin is therefore not yet discoverable through a catalog and has no public plugin Git URL to give users.

Publishing should use a dedicated repository whose root is the exporter output. After the exported repository is public, the user flow is:

```bash
omarchy plugin add https://github.com/<owner>/<face-setup-plugin>.git --enable
```

Users can later update through Omarchy's plugin management command. System authentication setup remains a separate, explicit action in the panel; adding or enabling the plugin does not install Howdy, enroll a face, change PAM, or open the camera.

## Release procedure

1. Generate the plugin export from a reviewed source commit.
2. Run `omarchy plugin validate` on the export and inspect that its root manifest names `surface.face-setup`.
3. Publish the export as the root contents of the dedicated public Git repository. Preserve a traceable source revision in the release notes.
4. Test `omarchy plugin add <git-url> --enable`, panel open/close, readiness refresh, language switching, and selected-feature setup on a supported Omarchy machine.
5. Only after those checks, publish or request a catalog listing using Omarchy's current catalog process.

The verified reference target is Surface Laptop 5 on Omarchy 4.5.0rc1. Other Surface camera hardware and Omarchy releases need separate validation. The plugin coordinates Howdy and PAM; it does not claim Windows Hello-equivalent anti-spoofing or camera cancellation guarantees.
