# Rydio

A push-to-talk app for riders: hold a button, talk, release. Everyone on
the same "channel" (just a name you type) hears you, over WiFi or
Bluetooth — no servers, no accounts, no internet required for that part.

On top of that, Rydio now has a full redesigned shell: a startup screen,
Google Sign-In, and a 3-tab app (Home, Nearby Rides, Profile) with a
**Share Ride Plan** feature for posting bike rides (or any group outing)
that says which comms mode — Walkie Talkie or Intercom — the group will
use. See *What's new: the Rydio redesign* below for the full tour, and
*Google Sign-In & Firebase setup* for the one external setup step needed
to make sign-in and ride-sharing actually work (the app builds and runs
fine without it — those two features just show a friendly "not set up
yet" message until you do).

- **WiFi mode** — every phone on the same WiFi network or hotspot joins the
  same channel directly (UDP multicast). Works for two phones or a group,
  Android and iOS.
- **Bluetooth mode** — no network needed. One phone "hosts" the channel;
  everyone else connects to it. **Android only** (see *Why Bluetooth is
  Android-only* below) — this is a limit of what iOS allows apps to do over
  Bluetooth, not something this app can work around.
- **Intercom mode** — built for riding with friends who are spread out, not
  just in Bluetooth range. Hands-free (no button — voice-activated), works
  over mobile data at whatever distance your signal reaches, and needs a
  small relay server you deploy once (see *Intercom mode* below).

This was written outside of the Flutter tool, so the Dart source (`lib/`)
and `pubspec.yaml` are ready to go, but the platform folders (`android/`,
`ios/`) need to be generated once by the real Flutter SDK on your machine —
that only takes a minute (Step 1 below).

## Just want an installable APK? (no Flutter install needed)

This repo includes a GitHub Actions workflow
(`.github/workflows/build-apk.yml`) that builds the APK for you on
GitHub's own machines — you don't need Flutter, Android Studio, or
anything else installed locally:

1. Create a free [GitHub](https://github.com) account if you don't have
   one, then create a new **empty** repository.
2. Upload this project into it. Easiest way with no `git` command line:
   on the new repo's page, click **Add file → Upload files**, drag in
   everything from this unzipped folder (including the hidden `.github`
   folder — if your file browser hides it, show hidden files first), and
   commit.
3. Go to the repo's **Actions** tab. A run named "Build APK" starts
   automatically (pushing is what triggers it); if it doesn't, open the
   workflow and click **Run workflow**.
4. Once it finishes (green check, a couple of minutes), open that run and
   scroll to **Artifacts** at the bottom — download `walkie-talkie-apk`.
   It's a zip containing `app-release.apk`.
5. Get that `.apk` onto your phone (email it to yourself, upload to
   Google Drive, or plug the phone in and copy it over), open it on the
   phone, and allow "install from this source" when Android asks — it's
   signed with this project's own throwaway `signing/rydio-release.jks`
   key (not a Play Store key), so Android will flag it as from an unknown
   source; that's expected for a self-distributed APK, not a sign
   anything's wrong. Every build uses that same committed key, which is
   also what keeps the app's SHA-1 fingerprint constant across rebuilds —
   see *Google Sign-In & Firebase setup* for why that matters.

This builds **Android only** (Bluetooth and Intercom mode both work on
it; WiFi mode too). For iOS you need a Mac with Xcode — there's no way
around that; it's an Apple requirement for every iOS app, not something
specific to this one.

If you'd rather build locally (you already have Flutter + Android
Studio), skip straight to Step 1 below and finish with:

```bash
flutter build apk --release
```

The APK lands at `build/app/outputs/flutter-apk/app-release.apk`.

## Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and
  working (`flutter doctor`).
- Two physical phones to actually test with — an emulator/simulator has no
  real microphone, WiFi radio, or Bluetooth radio, so push-to-talk can't be
  meaningfully tested on one.
- For Bluetooth mode: two Android phones.
- For Intercom mode: [Node.js](https://nodejs.org) 18+ to run the relay
  server (only needed wherever you deploy it, not on the phones).

## Step 1 — scaffold the platform folders

From inside this project folder:

```bash
flutter create . --project-name walkie_talkie --org com.example
flutter pub get
```

This fills in `android/`, `ios/`, and a few other files `flutter create`
normally generates, without touching the `lib/` or `pubspec.yaml` you
already have. Use your own reverse-domain for `--org` if you have one
(e.g. `com.yourname`).

## Step 2 — add the permissions

### Android

Open `android/app/src/main/AndroidManifest.xml` and add these lines inside
the `<manifest>` tag, above `<application ...>`:

```xml
<!-- WiFi / local network -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />

<!-- Microphone -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />

<!-- Bluetooth: Android 11 and below -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />

<!-- Bluetooth: Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
```

Also check `android/app/build.gradle` (or `build.gradle.kts`) has
`minSdkVersion`/`minSdk` of at least **23** — `flutter create` usually sets
this automatically, but the Bluetooth plugin needs it.

### iOS

Open `ios/Runner/Info.plist` and add, inside the outermost `<dict>`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Walkie-Talkie needs the microphone to transmit your voice.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Walkie-Talkie uses your local WiFi network to talk to nearby phones.</string>
```

(Bluetooth mode doesn't run on iOS — see below — so no Bluetooth keys are
needed there. Intercom mode works fully on iOS, since it's just a
WebSocket connection — no extra `Info.plist` keys needed beyond the
microphone one above.)

## Step 3 — run it on two phones

Plug in both phones (or run one from each of two terminals/IDE windows),
then for each:

```bash
flutter run -d <device-id>
```

(`flutter devices` lists the device ids.) On the first run, each phone will
ask for microphone permission, and for Bluetooth permission if you try
Bluetooth mode — allow both.

On the home screen, type a name and the same **channel name** on both
phones, then tap **Start over WiFi** on both (they need to be on the same
WiFi network or the same phone hotspot). Hold the big button to talk,
release to stop.

Intercom mode is a separate flow — see *Intercom mode* below for how to
set up and use it, including the one extra step (a relay server) it needs
that WiFi/Bluetooth mode don't.

## What's new: the Rydio redesign

The app now opens into a proper shell instead of straight into the old
name/channel form:

- **Splash screen** (`lib/screens/splash_screen.dart`) — the RYDIO
  wordmark over a black-to-white gradient with the hand-drawn rider
  illustration animating into place, then routes you to Login or
  straight into the app depending on whether you're already signed in.
- **Login screen** (`lib/screens/login_screen.dart`) — black & white
  themed, "Continue with Google" sign-in. A successful sign-in fills
  your name, email and photo straight from your Google account — there's
  no separate "fill in your profile" step.
- **App shell** (`lib/screens/app_shell.dart`) — a floating pill bottom
  nav with exactly 3 destinations (Home, Nearby Rides, Profile) and a
  center **+** button that opens **Share Ride Plan** from anywhere.
  - **Home** (`lib/screens/home_tab.dart`) — a greeting header plus the
    two big mode cards: tap **Walkie Talkie Mode** for the WiFi/Bluetooth
    flow (`walkie_talkie_setup_screen.dart`, the old home screen content,
    restyled), or **Inter-Com Mode** for the existing Intercom setup flow.
  - **Nearby Rides** (`lib/screens/nearby_rides_tab.dart`) — a live feed
    of ride plans other riders have shared.
  - **Share Ride Plan** (`lib/screens/share_ride_plan_screen.dart`) —
    title, description, meeting point, date/time, and a Walkie
    Talkie/Intercom mode picker; posting it adds it to everyone's Nearby
    Rides feed.
  - **Profile** (`lib/screens/profile_tab.dart`) — your Google avatar,
    name and email, plus sign out.

Ride plans are stored in Cloud Firestore so they're actually shared
between everyone using the app, not just stored on your own phone — which
is also why Google Sign-In needs the real external setup below (there's
no way to have a shared, multi-user feature with zero backend of any
kind).

## Google Sign-In & Firebase setup

This build ships with **placeholder** Firebase credentials
(`lib/firebase_options.dart`, `lib/services/auth_config.dart`) so the app
compiles and the APK builds fine with no setup at all — but "Continue
with Google" and the Nearby Rides feed need a real (free) Firebase
project before they'll actually work. Until you do this, tapping
"Continue with Google" shows a friendly "not set up yet" sheet with a
"Skip for now" button, so you can still reach and demo the rest of the
app.

1. **Create a Firebase project** at
   [console.firebase.google.com](https://console.firebase.google.com) —
   "Add project", any name, Google Analytics is optional.
2. **Add an Android app** to it: package name `com.example.walkie_talkie`
   (or whatever `--org` you used in Step 1), and paste in this **fixed
   SHA-1**:

   ```
   47:A6:F8:5F:23:65:5D:A2:B4:A9:08:E7:77:2B:C8:D7:B4:4F:DF:BF
   ```

   This is the fingerprint of the committed `signing/rydio-release.jks`
   keystore the GitHub Actions workflow signs every build with (see
   *Sign release builds with a fixed keystore* in `build-apk.yml`) — it's
   the same on every rebuild, so you only ever register it once. If you
   build locally with your own debug key instead, run
   `./gradlew signingReport` inside `android/` and use that SHA-1 instead.
3. Download the `google-services.json` Firebase gives you (you don't
   need to actually place this file anywhere — this project doesn't use
   the Gradle plugin that reads it, since `firebase_options.dart` carries
   the same values in Dart instead).
4. **Enable Google as a sign-in provider**: Firebase Console →
   Authentication → Sign-in method → Google → Enable.
5. **Enable Cloud Firestore**: Firebase Console → Firestore Database →
   Create database → start in test mode (fine for personal/small-group
   use; tighten the rules before sharing this widely).
6. **Fill in the real values**:
   - In `lib/firebase_options.dart`, replace the `android` `FirebaseOptions`
     fields (`apiKey`, `appId`, `messagingSenderId`, `projectId`,
     `storageBucket`) with the matching values from Project Settings →
     your Android app, or from `google-services.json`.
   - In `lib/services/auth_config.dart`, replace `kGoogleServerClientId`
     with the **Web client ID** from Authentication → Sign-in method →
     Google → "Web SDK configuration" (not the Android client ID —
     Google Sign-In needs the Web one to produce a token Firebase can
     verify).
7. Commit those two files and push — the next CI build (or local
   `flutter build apk --release`) will have working Google Sign-In and
   shared ride plans.

(The easier, more official alternative to steps 3 and 6 is installing the
[FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) and
running `flutterfire configure` from the project root, which generates a
real `lib/firebase_options.dart` for you automatically.)

## How it works

- **Protocol** (`lib/protocol/packet.dart`) — one small binary message
  format shared by all three transports: a type byte (hello / bye /
  talk-start / talk-end / audio), a channel tag, a sender id, and a
  payload.
- **WiFi transport** (`lib/transport/wifi_transport.dart`) — every phone
  sends to, and listens on, the same UDP multicast address. There's no
  server; "the channel" is just a filter on the channel tag in each packet.
  This is why WiFi mode handles two phones or a group with no extra code —
  a group is simply more phones listening to the same multicast traffic.
- **Bluetooth transport** (`lib/transport/bluetooth_transport.dart`) —
  Bluetooth Classic (RFCOMM) connections are always one-to-one, so one
  phone hosts a small server and relays whatever it hears from one
  connected phone to every other connected phone.
- **Internet relay transport** (`lib/transport/internet_relay_transport.dart`
  + `relay_server/`) — Intercom mode's transport. Same presence design as
  WiFi (periodic hello / timeout), but carried over a WebSocket to a small
  relay server instead of local multicast, which is what gives it real
  range. Adds auto-reconnect and a one-to-one "whisper" option on top.
- **Audio** (`lib/audio/`) — the mic is captured as raw 16kHz mono PCM16
  (via the `record` package) in small chunks, sent as-is (no compression —
  simpler, and plenty of bandwidth for voice on WiFi, Bluetooth, and
  typical mobile data), and played back with `flutter_pcm_sound`. WiFi and
  Bluetooth feed each chunk the moment it arrives; Intercom mode buffers
  briefly first (`AudioPlayer`'s `playoutDelay`) to smooth out the extra
  arrival jitter of a cellular link. `VoiceActivityDetector` is what makes
  Intercom mode hands-free — see *Intercom mode* above.
- **`PttController`** (`lib/services/ptt_controller.dart`) glues the audio
  and whichever transport is active together, and is the one thing the UI
  talks to — for WiFi/Bluetooth's push-to-talk, and for Intercom mode's
  voice-activated talking, mute/deafen, and whisper.

## Why Bluetooth is Android-only

Hosting (and therefore joining) over Bluetooth needs a classic Bluetooth
*server socket* (RFCOMM/SPP) — the same mechanism a Bluetooth printer or
car stereo uses. Android exposes this to any app. iOS does not: Apple only
lets third-party apps use this with officially licensed accessories (the
"MFi" program) or with Bluetooth Low Energy, which is far too low-bandwidth
for real-time voice. This is an Apple platform restriction, not a
limitation of this app or the plugin it uses — there's no workaround short
of an MFi hardware accessory. WiFi mode has no such restriction and works
fully on iOS.

## Intercom mode

Intercom mode is for riding with friends: pair your earphones, tap **Go
live**, and just talk — no button, no screen to look at. It's a separate
mode from WiFi/Bluetooth because it solves a different problem: WiFi needs
one network and Bluetooth needs ~10 m, but a group riding together is
often hundreds of meters or kilometers apart with nothing in common but
mobile signal. So Intercom mode talks over the internet instead, through a
small relay server everyone in the group points at.

### Deploy the relay

The relay (`relay_server/`) is a small Node.js WebSocket server — it has
no idea what a "channel" is, it just forwards bytes between phones that
are using the same channel tag. It's deliberately tiny (one file, one
dependency) so it's cheap and easy to self-host.

**Option A — Render.com free tier (quickest to get going):**

1. Push this project (or just the `relay_server/` folder) to a GitHub repo.
2. On [Render](https://render.com), create a new **Web Service** from that
   repo, with root directory `relay_server`, build command `npm install`,
   start command `npm start`.
3. Render gives you a URL like `walkie-relay.onrender.com`. In the app,
   enter it as `wss://walkie-relay.onrender.com` (note **`wss://`**, not
   `https://`).

Be aware: **Render's free tier drops idle WebSocket connections after about
5 minutes**, regardless of whether the ride is still going — this isn't a
bug in this app, it's how their free tier works. The app's auto-reconnect
(see below) papers over this automatically — you'll see a brief "Connection
lost — reconnecting…" status and it rejoins within a few seconds — but if
that's annoying, a cheap always-on VPS (e.g. a $4–6/month DigitalOcean or
Hetzner box) running `node server.js` behind a reverse proxy with TLS has
no such limit. (Fly.io's old free tier, if you've used it before, no
longer exists as of 2026 — it's trial-only now.)

**Option B — Any VPS or server you already have:**

```bash
cd relay_server
npm install
PORT=8080 node server.js
```

Put it behind a TLS-terminating reverse proxy (Caddy, nginx, or your
host's built-in one) so you can give the app a `wss://` address — plain
`ws://` works for local testing but phones on mobile data need TLS in
practice.

Everyone riding together just needs the **same relay address** — it's not
baked into the app on purpose, so you're never dependent on infrastructure
this project's authors control.

### Premium features (all free, no in-app purchases)

- **Voice-activated (VOX) talking** — no push-to-talk button; a short
  on-device voice detector (`lib/audio/voice_activity_detector.dart`)
  opens your mic to the group the instant you start talking and closes it
  again shortly after you stop. Adjustable sensitivity in Intercom's
  settings (the sliders icon).
- **Mute / deafen** — mute stops your mic instantly regardless of VOX;
  deafen stops you hearing others, without the "left the channel"
  announcement that actually leaving would send.
- **Whisper** — tap any rider in the participant list to talk privately to
  just them (tap again, or use the banner's "Back to everyone", to return
  to the group). Internet relay only — there's no equivalent for
  WiFi/Bluetooth mode's simpler broadcast design.
- **Signal quality indicator** — a green/orange/red dot per rider, based on
  how recently their phone has been heard from, so you can tell a
  genuinely dropped connection from a few seconds of normal radio silence.
- **Auto-reconnect** — a dropped relay connection (a tunnel, a cell
  handoff, a free host cycling your connection) reconnects on its own with
  increasing backoff; you'll see it in the status line, not as a crash.
- **Noise suppression & echo cancellation** — on by default for every mic
  capture in this app, not just Intercom mode (`lib/audio/audio_capture.dart`).

### Why VOX saves battery (and mobile data)

The microphone has to keep sampling continuously either way — that part's
unavoidable if the app is going to notice when you start talking without a
button. What VOX actually saves is **radio use**: sending audio over the
cellular network is the expensive part, battery- and data-wise, and VOX
only does that for the fraction of a ride you're actually mid-sentence,
instead of streaming the whole ride (or requiring you to remember to tap a
button every time, which rather defeats "hands-free").

### Background operation

Intercom mode keeps the screen on while it's running (via `wakelock_plus`,
toggleable in settings) so Android/iOS don't suspend the mic and
network connections to save power — this app does **not** implement a
native background/foreground service, so if you manually lock the phone
or switch apps, Intercom mode will likely pause until you come back to it.
For most riding setups (phone mounted, screen on) this isn't an issue in
practice; it's listed here so it isn't a surprise.

## Known limitations

- **No encryption.** Audio is sent as plain, uncompressed PCM. Fine for a
  WiFi network or Bluetooth pairing you trust (home, campsite, job site);
  don't rely on it for anything sensitive.
- **Guest/public WiFi often blocks this.** Many public, hotel, and office
  WiFi networks enable "client/AP isolation," which stops phones from
  talking to each other even on the same network. If WiFi mode can't find
  anyone, that's the most common reason — try a personal hotspot instead,
  or switch to Bluetooth (Android).
- **Bluetooth range/stability.** The host must stay nearby and on-screen
  (or at least not force-quit) to keep relaying; typical Bluetooth Classic
  range is ~10 m indoors.
- **One speaker at a time.** Like a real walkie-talkie, if two people hold
  the button (or, in Intercom mode, talk) at once, both transmissions
  arrive and play — there's no mixing of simultaneous speakers in any
  mode.
- **Intercom mode needs a relay you deploy** (see *Intercom mode* above) —
  there's no address built in, by design, so the app has no dependency on
  infrastructure outside your control.
- **Intercom mode has no native background mode.** It relies on keeping
  the screen on, not a foreground service; see *Background operation*
  above.
- **VOX can mistrigger on loud wind/engine noise**, especially at high
  sensitivity. Lowering the sensitivity slider in Intercom's settings
  usually fixes this; it trades off against picking up a quieter voice.
