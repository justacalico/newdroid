# Project rules

- Conventional commits required (`type: 中文描述`), cocogitto computes
  versions and the changelog from them. Use a merge commit (no squash) when
  merging MRs so every conventional commit is preserved.
- Never commit on `main`: branch -> commit -> push -> `glab mr create` ->
  merge -> `git checkout main && git pull`.
- Never edit `CHANGELOG.md` or version strings by hand. `cog bump` owns both.

## Verify locally

```bash
flutter pub get
flutter analyze
flutter test --coverage
# coverage gate is 100% lines:
python3 - <<'PY'
cur=None; miss=[]
for line in open('coverage/lcov.info'):
    line=line.strip()
    if line.startswith('SF:'): cur=line[3:]
    elif line.startswith('DA:') and int(line[3:].split(',')[1])==0:
        miss.append(f"{cur}:{line[3:].split(',')[0]}")
print('\n'.join(miss) if miss else '100% covered')
PY
```

- Golden tests live in `test/golden_test.dart`; regenerate with
  `flutter test --update-goldens` on Linux only (goldens are
  platform-dependent).

## CI layout

- `.gitlab-ci.yml` on `linux-truenas` mirrors branches/tags to the
  `justacalico/newdroid` GitHub repo and watches the GitHub run.
- `.github/workflows/build.yml` verifies (analyze + tests + `cog check`),
  builds signed APK/AAB on main and tags, publishes nightly and versioned
  releases, then triggers `github-release-sync` back on GitLab.
- Android signing comes from `android/app/key.properties`, injected in CI;
  the keystore and passwords live only in `~/Desktop/newdroid-signing/` and
  GitHub secrets.
