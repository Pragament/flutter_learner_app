// App-wide constants.
//
// IMPORTANT: paste your Firebase project's **Web client ID** here.
// Find it in Firebase Console -> Authentication -> Sign-in method -> Google ->
// "Web SDK configuration" -> Web client ID, OR in google-services.json under
// oauth_client with "client_type": 3.
//
// On Android, google_sign_in v7 needs this as the serverClientId so that the
// returned idToken is accepted by Firebase. Without it, sign-in returns a token
// Firebase will reject.
const String kGoogleServerClientId =
    'PASTE_YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
