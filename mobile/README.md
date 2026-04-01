# Mobile

Starter struktury aplikacji Flutter dla Zakupy.

## Status

Ten katalog nie został wygenerowany przez `flutter create`, bo Flutter SDK nie jest dostępny w tym środowisku. Struktura `lib/` jest już przygotowana pod MVP i można ją zachować po bootstrapie.

## Gdy Flutter będzie dostępny

```bash
cd mobile
flutter create .
flutter pub get
flutter run --dart-define=API_BASE_URL=https://twoj-host.tailnet.ts.net
```

Po wygenerowaniu projektu:
- zostaw istniejące pliki w `lib/`
- dostosuj `pubspec.yaml`, jeśli `flutter create` nadpisze część ustawień
- ustaw adres API na backend dostępny przez Tailscale

## Real devices

Aplikacja zapisuje sesję lokalnie, więc po logowaniu nie trzeba ręcznie wklejać tokena.

Ważne dla testów na telefonach:
- nie używaj `localhost` ani `127.0.0.1` dla backendu na fizycznym urządzeniu
- użyj adresu Tailscale lub Caddy osiągalnego z telefonu
- najlepiej uruchamiaj backend po HTTPS, zwłaszcza na iPhone
