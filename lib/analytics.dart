// Anonimowe statystyki (GoatCounter – bez ciasteczek i bez danych osobowych).
// W wersji przeglądarkowej wysyła zdarzenia do licznika,
// w wersji na telefon (APK) nic nie robi.
export 'analytics_stub.dart' if (dart.library.js_interop) 'analytics_web.dart';
