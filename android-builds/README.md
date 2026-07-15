# 📱 KRCE Smart Campus Mobile Application - Release Management

This directory serves as the centralized distribution hub and build repository for the Android mobile application APK binaries. It provides non-developer team members and testing coordinators with direct access to stable, versioned builds of the application without requiring compilation setups.

---

## 📂 Directory Structure

```text
android-builds/
├── latest/
│   └── app-release.apk      <-- Always holds the latest stable release
├── archive/
│   ├── v1.0.0/
│   │   └── app-release.apk  <-- Archived release binaries
│   ├── v1.0.1/
│   └── ...
├── release-notes/
│   ├── template.md          <-- Markdown notes template
│   ├── v1.0.0.md            <-- Release notes for v1.0.0
│   └── ...
└── README.md                <-- Release procedure documentation (This file)
```

---

## ⬇️ How to Download the Latest Build

1. Navigate to the [android-builds/latest/](latest/) folder in the repository web interface.
2. Select the [app-release.apk](latest/app-release.apk) file.
3. Click the **Download** (or **Raw**) button in the top right of the file viewer.
4. Transfer the file to your Android device via USB, email, or drive, and install it (requires enabling "Install from Unknown Sources").

Alternatively, download builds directly from the **GitHub Releases** page where the APK is permanently attached to tagged version assets.

---

## 🏷️ Version Naming Convention

This project strictly adheres to [Semantic Versioning (SemVer)](https://semver.org/) format: `vMAJOR.MINOR.PATCH`

- **MAJOR**: Incompatible database, API, or architectural changes (e.g. `v2.0.0`).
- **MINOR**: Backward-compatible new features (e.g., adding breakdown modules: `v1.1.0`).
- **PATCH**: Backward-compatible bug fixes and security hotfixes (e.g., fixing RFID sort: `v1.0.1`).

---

## 🚀 Release Workflow

### Automated Release (GitHub Actions)
The repository is integrated with a DevOps compilation pipeline.
1. When code changes are committed and pushed to the `main` branch, or when a tag matching `v*` is pushed:
   - The runner starts compilation and runs standard checks.
   - Builds the Flutter application APK.
   - Saves the compiled binary under artifacts.
   - Overwrites [latest/app-release.apk](latest/app-release.apk).
   - Archives the build under [archive/vX.Y.Z/](archive/) using the version from `pubspec.yaml` or git tag.
   - Deploys a new GitHub Release with the build notes.

### Manual Release (Local Maintenance)
If you need to manually package and distribute a build:
1. **Compile the APK**:
   ```bash
   cd frontend/krce_bus_flutter
   flutter build apk --release
   ```
2. **Retrieve the Build Version**:
   Read the version tag defined inside `pubspec.yaml` (e.g., `version: 1.1.0+1` translates to `v1.1.0`).
3. **Archive Previous Version**:
   - Move the current binary from `latest/app-release.apk` to `archive/v[OLD_VERSION]/app-release.apk`.
4. **Deploy New Version**:
   - Copy the newly built `build/app/outputs/flutter-apk/app-release.apk` into `latest/app-release.apk`.
5. **Document Release Notes**:
   - Duplicate `release-notes/template.md` to `release-notes/v[NEW_VERSION].md`.
   - Update version, release date, developer, feature logs, and resolved issue notes.
6. **Commit & Distribute**:
   - Stage and commit the files:
     ```bash
     git add android-builds/
     git commit -m "Release v[NEW_VERSION]"
     git push origin main
     ```

---

## 🛡️ Best Practices

- **Never Commit Broken Code**: Ensure the Flutter app compiles locally before pushing changes to the repository.
- **Update pubspec.yaml**: Increment the `version` field inside `pubspec.yaml` before every release to sync automated tagging.
- **Clean Builds**: Always run `flutter clean` before building an APK locally to avoid cache bloat.
- **Keep Release Notes Accurate**: Always document breaking changes, API adjustments, or new backend endpoints to help QA testers verify updates.
