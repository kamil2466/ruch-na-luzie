# Ruch Na Luzie

Bezpłatna aplikacja mobilna wspierająca codzienny ruch, spokojny oddech, emocje i relacje z innymi.
Pięć stref z ćwiczeniami krok po kroku, punkty, statystyki i certyfikat „Ambasador Dobrostanu”.

## Jak zacząć korzystać

Wejdź na stronę aplikacji (link w sekcji **About** po prawej stronie repozytorium) albo zeskanuj kod QR
z najnowszego wydania w zakładce **Releases**. Na stronie można:

- otworzyć aplikację w przeglądarce – działa na Androidzie i iPhonie, bez instalacji,
- pobrać plik `ruch-na-luzie.apk` i zainstalować go na telefonie z Androidem.

## Dla programistów

Aplikacja jest napisana we Flutterze. Cały kod znajduje się w pliku `lib/main.dart`.

Uruchomienie lokalne:

```bash
flutter create . --platforms=android,web --project-name ruch_na_luzie
flutter pub get
flutter run
```

Każda zmiana wysłana do gałęzi `main` automatycznie (GitHub Actions, plik `.github/workflows/build.yml`):

1. buduje plik APK i publikuje go w zakładce **Releases**,
2. buduje wersję przeglądarkową i publikuje ją na **GitHub Pages** razem ze stroną `strona/index.html` i kodem QR.

## Licencja

Projekt udostępniony na licencji MIT – szczegóły w pliku [LICENSE](LICENSE).
Możesz go bezpłatnie używać, kopiować, zmieniać i rozpowszechniać.
