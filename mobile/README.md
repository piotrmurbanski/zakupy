# Mobile

Starter struktury aplikacji Flutter dla Listek.

## Status

Ten katalog nie został wygenerowany przez `flutter create`, bo Flutter SDK nie jest dostępny w tym środowisku. Struktura `lib/` jest już przygotowana pod MVP i można ją zachować po bootstrapie.

## Gdy Flutter będzie dostępny

```bash
cd mobile
flutter create .
flutter pub get
flutter run --dart-define=API_BASE_URL=http://besztia.tail218f8.ts.net:8080
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
- dla tego repo:
  - `http://besztia.tail218f8.ts.net` wskazuje `prod`
  - `http://besztia.tail218f8.ts.net:8080` wskazuje `dev`
- najlepiej uruchamiaj backend po HTTPS, zwłaszcza na iPhone

## Android release signing

Repo obsługuje teraz dwa tryby buildu Android:
- bez `android/key.properties`: `release` podpisany debug key tylko do testów lokalnych
- z `android/key.properties`: właściwy release podpisany Twoim keystore

Przykładowa konfiguracja jest w `android/key.properties.example`.

Szybki flow:

```bash
cd mobile
mkdir -p keystore
keytool -genkeypair -v \
  -keystore keystore/zakupy-upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias zakupy-release
cp android/key.properties.example android/key.properties
flutter build apk --release --dart-define=API_BASE_URL=http://besztia.tail218f8.ts.net
```

Jeśli docelowo chcesz wrzucać aplikację do Google Play, zbuduj `appbundle` zamiast `apk`.
