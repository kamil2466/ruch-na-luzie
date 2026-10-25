import 'dart:js_interop';

/// Obiekt licznika GoatCounter dodany w web/index.html (może go nie być, np. przy blokerze reklam).
@JS('goatcounter')
external JSObject? get _goatcounter;

@JS('goatcounter.count')
external void _goatcounterCount(JSAny? options);

/// Wysyła anonimowe zdarzenie, np. "strefa-1-ukonczona".
void trackEvent(String name) {
  try {
    if (_goatcounter == null) return;
    _goatcounterCount({'path': name, 'title': name, 'event': true}.jsify());
  } catch (_) {
    // Statystyki nigdy nie mogą zepsuć działania aplikacji.
  }
}
