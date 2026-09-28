# MatchIQ Android and iOS

Flutter client with English, Somali and Arabic, RTL, dark/light themes, onboarding, authentication, fixture browsing, match centers, analysis, favorites, saved analyses, history, profile and subscription integration.

## Build

Use Flutter stable, Java 17, Android SDK 36 and NDK 28.2.13676358. Configure a private release key using `android/key.properties.example`. Actual `key.properties` and keystores are excluded from Git. Preserve the signing key for future app updates.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=API_URL=https://mach-iq-production.up.railway.app/api
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`.

Run the release APK on a dedicated emulator/device before publishing:

```powershell
./scripts/smoke-android.ps1 -Adb /path/to/android-sdk/platform-tools/adb.exe -Serial emulator-5554
```

Also inspect onboarding and fixture loading visually. This runtime check catches native startup crashes that Dart widget tests cannot detect. The release ProGuard rule preserves WorkDatabase_Impl's reflective constructor; without it, R8 removes that constructor and WorkManager crashes before Flutter starts.

## External configuration

- Set API_FOOTBALL_KEY only on Laravel in Railway. Never include provider secrets in this app.
- The default account flow needs only name and email. A random secret in device secure storage authenticates it; contact email does not claim or recover an existing account. Keep app data to retain access. Existing password accounts can still sign in. Email verification is not required for analysis or sent on registration.
- Configure SMTP on Laravel for legacy password resets.
- Configure native Firebase projects and providers, then build with FIREBASE_ENABLED=true. Default builds explain that social sign-in and push are unavailable.
- Set REVENUECAT_PUBLIC_KEY as a Dart define after configuring actual store products and the pro entitlement. Server verification requires RevenueCat credentials on Laravel.
- Ads are disabled without ADMOB_BANNER_ID. Set the real ADMOB_APP_ID Gradle property before distributing ads; default native app ID is Google's official test ID. Pro accounts are excluded. Unverified reward callbacks do not grant credits.
- iOS compilation/signing requires macOS and Xcode.

Complete native-device tests, operator privacy/contact information and store setup before store publication. Statistical estimates are not guaranteed results. External integrations remain unverified until real credentials are configured.
