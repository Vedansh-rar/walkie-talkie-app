/// Google Sign-In needs a **Web** OAuth client id (not the Android one) as
/// its `serverClientId` so the ID token it returns can be verified by
/// Firebase Auth. This is generated automatically once you add an Android
/// app to a Firebase project and enable the Google sign-in provider — grab
/// it from Firebase Console → Authentication → Sign-in method → Google →
/// "Web SDK configuration" → Web client ID (or the "Web client (auto
/// created by Google Service)" entry in Google Cloud Console → Credentials).
///
/// This placeholder compiles and builds fine; Google Sign-In will just
/// fail at runtime with a clear "not configured" message (see
/// [AuthService]) until you paste in the real value. See the README's
/// "Google Sign-In setup" section.
const String kGoogleServerClientId =
    'REPLACE_WITH_YOUR_FIREBASE_WEB_CLIENT_ID.apps.googleusercontent.com';

bool get isGoogleSignInConfigured => !kGoogleServerClientId.startsWith('REPLACE_WITH_');
