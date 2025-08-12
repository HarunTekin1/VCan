## VCan App

Flutter + Firebase (Auth, Firestore placeholder) Basis.

### Aktueller Stand
* Firebase init über `firebase_options.dart`
* Einfaches E-Mail/Passwort Login (Auto-Register falls User fehlt)
* Theme (Light/Dark) an Website-Farben angelehnt
* Platzhalter Gruppenliste (static)
* Riverpod vorbereitet (noch keine Provider außer Root Scope)

### Nächste Schritte (Vorschlag)
1. Firestore Security Rules hinzufügen (`firestore.rules`)
2. Domain-Ordnerstruktur anlegen (`features/auth`, `features/groups` ...)
3. State aus UI lösen (Repository + Provider pro Feature)
4. Fehler- & Loading-States vereinheitlichen (z.B. AsyncValue / sealed Klassen)
5. Gruppe Detail + Nachrichtenmodell entwerfen
6. Routing (go_router) einsetzen sobald mehr Screens kommen
7. Lokalisierung (intl) vorbereiten
8. Logging & Crashlytics aktivieren

### Entwicklung
```
flutter pub get
flutter run
```

### Tests
```
flutter test
```

### Deployment – Übersicht
Web Landing (statisch):
1. Ordner `web/webseite` bauen/prüfen
2. GitHub Pages oder Firebase Hosting (public: web/webseite) – `firebase init hosting`
3. Favicon PNG/ICO noch erzeugen

Flutter App (Android Release kurz):
```
flutter build appbundle --release
```
Liefert AAB unter `build/app/outputs/bundle/release/` für Play Store.

iOS (macOS nötig):
```
flutter build ipa --release
```

Web (Flutter App optional):
```
flutter build web --release
firebase deploy --only hosting (falls konfiguriert)
```

### Firebase Security (aktuell)
* Firestore: Gruppen nur lesbar für angemeldete User; keine Schreibrechte.
* Storage: Authentifizierte dürfen hochladen (später Dateityp/Größe prüfen).

### To Harden Before Production
* E-Mail-Verifizierung erzwingen (check user.emailVerified)
* Passwort-Reset Flow
* Rate Limits / AppCheck / reCAPTCHA (Web)
* Firestore Indizes & restriktive Regeln für zusätzliche Collections
* Logging & Crashlytics aktivieren

### Sicherheit
Aktuell jede Registrierung möglich; E-Mail Verifizierung & Passwort Reset fehlen noch.

### Lizenz
Proprietär / intern (anpassen).
