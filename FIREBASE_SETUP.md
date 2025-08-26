Firebase setup checklist for VCan

This file documents the exact steps and values needed to configure Firebase / Google OAuth / PhoneAuth and App Check so Google Sign-In and Phone Authentication work correctly.

Project info (from `android/app/google-services.json`):
- Firebase project_id: vcan-c74cc
- Firebase project_number: 490354986336
- Android package names in current `google-services.json`:
  - com.example.vcan
  - com.vcan.app

Debug keystore fingerprints (from local debug keystore):
- SHA-1: 35:EE:F1:49:48:8F:29:79:0E:98:49:E4:CE:55:91:47:32:6A:0F:5E
- SHA-256: 6E:BD:BD:36:0B:A0:03:72:20:CD:3F:E3:BD:A5:F0:C7:60:B4:C9:5A:A0:65:32:5A:68:AC:F2:4F:F0:57:43:EB

Required manual steps (Firebase Console + Google Cloud)

1) Add SHA fingerprints to Firebase (Android app)
- Console: https://console.firebase.google.com
- Select project: vcan-c74cc
- Go to Project Settings (gear) → Your apps → Android
- For each Android app (package name), click the app and add the SHA-1 and SHA-256 fingerprints.
  - Add the debug SHA values above for local testing.
  - If you have a release keystore, add the release SHA-1 and SHA-256 as well (see notes below).
- After adding fingerprints, download the updated `google-services.json` and place it in `android/app/` (overwrite existing file).

2) Configure Google Sign-In (OAuth consent & clients)
- Go to Google Cloud Console → APIs & Services → Credentials.
- Ensure an OAuth 2.0 Client for Android exists with:
  - Package name: one of `com.example.vcan` or `com.vcan.app` (match the one you build)
  - SHA-1 fingerprint: the same you added to Firebase.
- If not present, create a new OAuth client (Application type: Android).
- In Firebase Console → Authentication → Sign-in method → enable Google.

3) Phone Authentication (testing and production)
- In Firebase Console → Authentication → Sign-in method → Phone: enable.
- For testing without real SMS (recommended during dev):
  - Authentication → Sign-in method → Phone → Add phone numbers for testing.
  - Add a test number and a verification code (e.g. +15551234567 -> 123456) then use it in the app to bypass real SMS.
- For production on Android, ensure either:
  - Play Integrity API / SafetyNet and reCAPTCHA are configured (see Firebase docs), or
  - Use the reCAPTCHA verifier: set site key in Google Admin & ensure invisible reCAPTCHA is set up. See: https://firebase.google.com/docs/auth/android/phone-auth

4) App Check (optional but recommended)
- In Firebase Console → App Check: register App Check providers (Play Integrity or SafetyNet for Android).
- Follow the onboarding steps to enable enforcement if desired.

5) Download and replace `google-services.json`
- After steps (1) and (2), download the new `google-services.json` from Firebase Project Settings and copy to `android/app/google-services.json`.
- Commit and push the updated file to the branch used for release (avoid including secret keys publicly if that is a concern — consider using CI secrets instead).

6) Release keystore (production)
- If you sign release builds, obtain the release keystore fingerprint(s):

  keytool -list -v -alias <alias> -keystore "path\to\release-keystore.jks"
  (storepass/keypass per your keystore)

- Add release SHA-1/256 to Firebase and Google Cloud OAuth clients as in step (1) and (2).
- If using Google Play App Signing, upload the app and add the Play signing certificate SHA to Firebase (via release flow) or retrieve the upload/Play signing keys from the Play Console.

7) After updating `google-services.json` and committing:
- Run local checks:
  - flutter clean
  - flutter pub get
  - flutter analyze
  - flutter run -d <device>
- Test Google Sign-In and Phone Auth flows.

Automation & what I can do for you if you grant access
- If you want me to perform actions directly (create OAuth clients, add SHA fingerprints, download google-services.json), I need one of:
  - Firebase/Google Cloud owner access from your account (I cannot authenticate into your console from this environment). Alternatively:
  - A service account JSON with permissions (IAM) to manage OAuth clients and apps, plus the Firebase CLI authenticated on this machine.

What I already did in this repo
- Found existing `android/app/google-services.json` pointing to project `vcan-c74cc`.
- Retrieved debug keystore fingerprints and recorded them above.
- Added CI workflow `.github/workflows/flutter-analyze.yml` and committed it to the `feat/welcome` branch.

Next recommended immediate actions for you (short):
1. Add the debug SHA values above to Firebase Android app(s).
2. Download the updated `google-services.json` and place it into `android/app/`.
3. If you have a release keystore, get its SHA and add it as well.
4. Enable Google Sign-In and Phone Auth in Firebase and add test phone numbers for dev.
5. Run `flutter run` and verify the flows.

If you prefer I do the console changes automatically, provide one of the following:
- A temporary Google Cloud service account key (JSON) with rights to edit OAuth clients and Firebase project settings (not recommended unless you trust automation), or
- Grant me OAuth-based access via a browser flow (you must perform interactive login on your machine); I can provide exact commands to run locally.

Questions? If you're ready, tell me to:
- "I will add SHAs myself" (then upload the new `google-services.json` here and I'll commit it), or
- "Give service account" (and provide the JSON path and scope), or
- "Guide me" (I'll walk you step-by-step while you click in the Console).
