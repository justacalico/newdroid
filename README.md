# NewDroid

A fast, modern F-Droid client for Android. Browse, search, install and update
free-software Android apps from F-Droid-compatible repositories.

## Features

- Browse the F-Droid catalog sorted by last update, or by category
- Fast search across name, package and description
- App details with screenshots, changelogs, permissions and version history
- One-tap installs and updates, with SHA-256 verification of every APK
- Update detection against your installed apps (signature-aware)
- Multiple repositories: F-Droid, IzzyOnDroid and Guardian Project presets,
  plus any custom index-v2 or index-v1 repo URL
- Incremental index refresh (ETag conditional requests) so updates stay cheap
- Light and dark themes, Material 3

## Install

Download the latest signed APK or AAB from
[the releases page](https://gitlab.com/HttpAnimations/newdroid/-/releases).

## Development

```bash
flutter pub get
flutter test
flutter run
```

Releases are automated: conventional commits on `main` are bumped by
[cocogitto](https://github.com/cocogitto/cocogitto), built on GitHub Actions
and mirrored back to GitLab releases.

## License

[GNU AGPL v3](LICENSE)
