# Release Signing — one-time setup (Windows)

`build.gradle` now reads `android/key.properties` (gitignored). Without it,
release builds keep falling back to the debug key, so nothing breaks today.

## 1. Generate the keystore (once, on the dev PC)

```powershell
mkdir C:\Users\rahul\vani\android\keystore
keytool -genkey -v `
  -keystore C:\Users\rahul\vani\android\keystore\vani-release.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias vani
```

(`keytool` ships with the JDK; it's at `%JAVA_HOME%\bin\keytool.exe`.)

## 2. Create `android/key.properties`

Copy `android/key.properties.example` → `android/key.properties`, fill in the
two passwords. `key.properties`, `*.jks`, `*.keystore` are all gitignored —
verify with `git status` before committing anything.

## 3. Build

```powershell
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`, now signed with the
release key.

## ⚠️ Back the keystore up

Losing `vani-release.jks` = losing the ability to ever update the app on
Play. Back it up off-machine (password manager + drive). Consider Play App
Signing at first upload so Google holds the app signing key and this keystore
becomes only the upload key.
