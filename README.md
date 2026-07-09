# flutter_learner_app

# Firebase Setup

This repository does **not** include Firebase configuration files because they contain private company credentials.

Before running the application, obtain the required Firebase configuration files from your project administrator or create them using your own Firebase project.

## Required Files

### Android

Place the Firebase configuration file at:

```text
android/app/google-services.json
```

### iOS (if applicable)

Place the Firebase configuration file at:

```text
ios/Runner/GoogleService-Info.plist
```

### Flutter Firebase Configuration

Generate the Firebase options file using the FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This will generate:

```text
lib/firebase_options.dart
```

---

## Install Dependencies

```bash
flutter pub get
```

---

## Run the Application

```bash
flutter run
```

---

## Notes

- Firebase configuration files are intentionally excluded from version control.
- Contact the project administrator to obtain the required configuration files.
- Do not commit Firebase credentials or service account keys to public repositories.

---

## Ignored Files

The following files are intentionally ignored:

```text
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
serviceAccountKey.json
```