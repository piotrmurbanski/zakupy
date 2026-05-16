# Listek

Prywatna aplikacja zakupowa dla dwóch użytkowników. Projekt celuje w prosty, utrzymywalny MVP:
- aplikacja mobilna we Flutterze dla Androida i iPhone
- backend REST w Node.js, Fastify i TypeScript
- PostgreSQL jako źródło prawdy
- wdrożenie na domowym VM przez Docker Compose
- dostęp prywatny przez Tailscale i reverse proxy Caddy

## Aktualny stan

W kodzie są już dostępne:
- logowanie i rejestracja z sesją JWT
- przywracanie sesji po starcie aplikacji mobilnej
- widok list i widok szczegółów listy
- tworzenie list
- współdzielenie list z innym użytkownikiem
- zmiana nazwy listy z widoku szczegółów przez właściciela
- dodawanie, edycja, usuwanie i odhaczanie pozycji
- odświeżanie danych po zapisie oraz okresowy refresh na ekranie list i w widoku szczegółów listy

## Synchronizacja między telefonami

Aktualny model synchronizacji jest prosty i oparty o polling:
- ekran list odświeża się automatycznie co 15 sekund
- widok szczegółów listy odświeża się automatycznie co 15 sekund
- nadal działa ręczny refresh przyciskiem oraz pull-to-refresh

W praktyce oznacza to:
- nowa udostępniona lista powinna pojawić się na drugim telefonie maksymalnie po około 15 sekundach, jeśli użytkownik jest na ekranie list
- dodany, usunięty albo zmodyfikowany element powinien pojawić się na drugim telefonie maksymalnie po około 15 sekundach, jeśli użytkownik ma otwartą tę listę

## Struktura repozytorium

```text
.
├── backend/   # API Fastify, Prisma, TypeScript
├── docs/      # architektura, plan MVP, API, notatki operacyjne
├── infra/     # docker-compose, Caddyfile, deployment notes
└── mobile/    # aplikacja Flutter
```

## Szybki start

### 1. Lokalny test na Macu przez Docker Desktop

Jeśli nie masz lokalnego PostgreSQL, użyj Dockera. To jest teraz domyślna ścieżka dla developmentu lokalnego.

```bash
cd infra
cp .env.example .env
docker compose up --build -d postgres backend
```

To uruchamia:
- PostgreSQL na `localhost:5432`
- backend na `http://localhost:3000`

Sprawdzenie:

```bash
curl http://localhost:3000/health
```

Pierwszy endpoint testowy:

```bash
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"supersecret123","displayName":"Piotr"}'
```

Logi:

```bash
docker compose logs -f backend
```

Zatrzymanie:

```bash
docker compose down
```

Jeśli chcesz też reverse proxy:

```bash
cd infra
cp .env.example .env
docker compose up --build -d
```

W [infra/.env.example](infra/.env.example) masz wszystkie zmienne do lokalnego uruchomienia, w tym `JWT_SECRET`. Ustaw tam własną wartość w `infra/.env`, zamiast trzymać sekret na sztywno w Compose.

### 2. Backend bez Dockera

```bash
cd backend
npm install
cp .env.example .env
npx prisma db push
npm run dev
```

API wystartuje domyślnie na `http://localhost:3000`.

### 3. Mobile

`mobile/` zawiera obecny kod Fluttera. Jeśli potrzebujesz odtworzyć brakujące pliki platformowe lokalnie:

```bash
cd mobile
flutter create .
```

Po wygenerowaniu zachowaj istniejący układ `lib/` i dopasuj pliki platformowe do tego kodu.

### 4. Flutter i backend razem

Najprostszy lokalny flow:

1. W jednym terminalu uruchom `docker compose up --build -d postgres backend` w [infra/](infra).
2. Sprawdź `curl http://localhost:3000/health`.
3. Wyślij `POST /auth/register`, żeby potwierdzić zapis do Postgresa.
4. W [mobile/](mobile) wykonaj `flutter create .`, potem `flutter pub get`.
5. Uruchom `flutter run --dart-define=API_BASE_URL=https://twoj-host.tailnet.ts.net` na simulatorze iOS albo emulatorze Android.

Na prawdziwych urządzeniach nie używaj `localhost` jako API URL. Telefon powinien łączyć się z backendem przez adres Tailscale/Caddy dostępny w sieci urządzenia, najlepiej po HTTPS.

## MVP

Zakres pierwszej wersji:
- rejestracja i logowanie
- tworzenie list zakupowych
- współdzielenie list z drugim użytkownikiem
- dodawanie, edycja, usuwanie i odhaczanie pozycji
- prosty sync oparty o odświeżanie danych po zapisie

To już pokrywa obecna implementacja backendu i mobile. Następne rozsądne kroki to dopięcie pełnego testowania end-to-end oraz dalsze uspójnianie UX pod użycie na dwóch realnych telefonach.

## CI/CD backendu

Repo jest teraz przygotowane pod w pełni automatyczny deployment na Ubuntu:
- CI: [`.github/workflows/backend-ci.yml`](.github/workflows/backend-ci.yml)
- auto deploy `develop -> dev`: [`.github/workflows/backend-deploy-dev.yml`](.github/workflows/backend-deploy-dev.yml)
- auto deploy `main -> prod`: [`.github/workflows/backend-deploy-prod.yml`](.github/workflows/backend-deploy-prod.yml)
- szablony Compose dla Ubuntu: [`infra/ubuntu/`](infra/ubuntu)
- instrukcja wdrożenia: [`docs/backend-cicd-ubuntu.md`](docs/backend-cicd-ubuntu.md)

Deploy jest wykonywany lokalnie na tym samym serwerze Ubuntu przez self-hosted GitHub runner, więc GitHub buduje i uruchamia wdrożenie, ale sam `docker compose` odpala się już wewnątrz Twojej prywatnej maszyny.

Docelowy przepływ jest taki:
1. pushujesz zmiany backendu na `develop`
2. GitHub Actions buduje obraz `dev` i self-hosted runner na Ubuntu wdraża środowisko developerskie
3. po weryfikacji mergujesz do `main`
4. GitHub Actions buduje obraz `stable` i ten sam serwer Ubuntu wdraża produkcję

To daje pełną automatyzację bez budowania backendu bezpośrednio na runtime host.

## Aktualizacja aplikacji mobilnej

Po wdrożeniu nowego flow backend będzie zwykle dostępny pod dwoma adresami:

```text
http://dev-api.twoj-serwer.tailnet.ts.net
http://api.twoj-serwer.tailnet.ts.net
```

Przed buildem lub instalacją aplikacji ustaw właściwy adres przez `--dart-define=API_BASE_URL=...`.
- buildy developerskie powinny wskazywać `dev`
- buildy dla stabilnego użycia powinny wskazywać `prod`

### Android

Na podłączonym urządzeniu albo emulatorze:

```bash
cd mobile
flutter pub get
flutter run --release -d <android-device-id> --dart-define=API_BASE_URL=http://dev-api.twoj-serwer.tailnet.ts.net
```

Jeśli chcesz tylko zbudować paczkę:

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=http://dev-api.twoj-serwer.tailnet.ts.net
```

Android release ma włączony `cleartext traffic`, żeby aplikacja mogła łączyć się z lokalnym backendem po `http://` podczas testów przez Tailscale. Jeśli później przejdziesz na HTTPS przez Caddy, ten wyjątek można z powrotem zawęzić albo usunąć.

Jeśli chcesz przygotować prawdziwy podpisany release zamiast builda debug-sign:

1. Wygeneruj keystore, na przykład:

```bash
cd mobile
keytool -genkeypair -v \
  -keystore keystore/zakupy-upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias zakupy-release
```

2. Skopiuj konfigurację podpisu:

```bash
cp android/key.properties.example android/key.properties
```

3. Uzupełnij `android/key.properties` własnymi hasłami i ścieżką do keystore.

4. Zbuduj podpisany APK:

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://api.twoj-serwer.tailnet.ts.net
```

5. Albo zbuduj AAB pod Google Play:

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=http://api.twoj-serwer.tailnet.ts.net
```

Konfiguracja Androida automatycznie użyje `android/key.properties`, jeśli plik istnieje. Jeśli go nie ma, `release` nadal zadziała na debug key tylko do testowej instalacji lokalnej.

### iPhone

Na iPhonie albo w symulatorze:

```bash
cd mobile
flutter pub get
flutter run --release -d <ios-device-id> --dart-define=API_BASE_URL=http://dev-api.twoj-serwer.tailnet.ts.net
```

Jeśli potrzebujesz samego buildu:

```bash
cd mobile
flutter build ios --release --dart-define=API_BASE_URL=http://api.twoj-serwer.tailnet.ts.net
```

Uwaga dla iPhone'a:
- obecna konfiguracja iOS nie ma wyjątku ATS dla czystego `http`
- na fizycznym iPhonie bezpieczniej używać adresu HTTPS przez Caddy albo Tailscale
- jeśli zostajesz przy HTTP, najłatwiej testować to na Androidzie albo w symulatorze iOS

## Codex run actions

Jeśli chcesz dodać w Codex gotowe akcje do buildów i deployów mobile, użyj wspólnego skryptu:

```bash
sh mobile/scripts/codex-mobile-action.sh <action>
```

Gotowa rozpiska polecanych akcji i wymaganych zmiennych jest w [docs/codex-mobile-actions.md](docs/codex-mobile-actions.md).

## Najbliższe kroki

1. Dopięcie pełnego testowania end-to-end na dwóch realnych urządzeniach.
2. Wyczyszczenie UX po wspólnym użyciu z drugą osobą.
3. Rozszerzenie mobile o zarządzanie listami poza tworzeniem i współdzieleniem, jeśli okaże się to potrzebne w codziennym użyciu.
