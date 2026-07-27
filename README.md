<div align="center">

# Rito

**A minimalist, offline-first period and cycle tracker.**

Your data never leaves your device.

</div>

---

## About

Rito is a period and cycle tracker built around a single principle:
**your reproductive health data is yours, and only yours.** There is no
account, no server, no analytics, no network access. Every log entry is
encrypted and stored locally, and the app can be locked behind
biometric authentication.

## Features

| | |
|---|---|
| 🗓️ **Calendar logging** | Track flow, symptoms, mood, discharge, stress, sleep, and sexual activity per day from a simple calendar view. |
| 🔮 **Cycle prediction** | Upcoming cycle days and phases — menstrual, follicular, ovulation, luteal — are predicted with a Bayesian network combined with a Kalman filter, blending your logged history with population-level priors (including a PCOS-adjusted model). |
| 💬 **Conversational log entry** | A small on-device assistant understands natural language — "log period today", "what happened on the 12th?" — and acts on it. No cloud model, no network calls; it runs entirely on-device via TFLite. |
| 🔐 **Encrypted local storage** | All data lives in [Hive](https://pub.dev/packages/hive_ce) boxes encrypted with an AES key held in the platform's secure storage (Keychain / Keystore) — never written to disk in plaintext. |
| 🔒 **Biometric app lock** | Optionally require Face ID, fingerprint, or device credential to reopen the app after backgrounding. |
| ✈️ **Fully offline** | No accounts. No analytics. No network required, ever. |

## Getting started

Rito is built with [Flutter](https://flutter.dev).

```bash
flutter pub get
flutter run
```

### Building a signed release

A signed release build needs your own keystore:

1. Generate a keystore with `keytool -genkey -v -keystore <name>.jks -keyalg RSA -keysize 2048 -validity 10000 -alias <alias>`
2. Create `android/key.properties` (already gitignored) with:
   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=...
   storeFile=<path-to-your-keystore>
   ```
3. Run `flutter build apk --release`

## Tech stack

- **Flutter / Dart** — cross-platform UI
- **Hive CE** — encrypted local storage
- **flutter_secure_storage** — encryption key storage
- **local_auth** — biometric app lock
- **statistics** — Bayesian network inference
- **tflite_flutter** — on-device NLP for the log-entry assistant

## License

[GPL-3.0](LICENSE)
