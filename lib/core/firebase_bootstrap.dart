/// Set during [configureFirebaseForApp] in `main.dart` if initialization fails.
/// Used on the login screen to distinguish "bad credentials" from a real bootstrap failure.
String? firebaseBootstrapLastError;
