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

Repo zawiera teraz prosty flow pod QNAP:
- CI: [`.github/workflows/backend-ci.yml`](.github/workflows/backend-ci.yml)
- publikacja obrazu: [`.github/workflows/backend-cd.yml`](.github/workflows/backend-cd.yml)
- produkcyjny Compose dla NAS-a: [`infra/docker-compose.qnap.yml`](infra/docker-compose.qnap.yml)
- instrukcja wdrożenia: [`docs/backend-cicd-qnap.md`](docs/backend-cicd-qnap.md)

Docelowy przepływ jest taki:
1. pushujesz zmiany backendu na `main`
2. GitHub Actions buduje i publikuje obraz do GHCR
3. QNAP pobiera nowy obraz przez `sh scripts/deploy-backend.sh`

To daje prosty, przewidywalny deployment bez budowania aplikacji na samym QNAP-ie.

## Aktualizacja backendu na QNAP

Najprostszy ręczny flow aktualizacji backendu:

1. Skopiuj pliki z `infra/` na QNAP:

```bash
scp -r infra/* administrator@192.168.0.40:/share/Container/zakupy/infra/
```

2. Zaloguj się na serwer i przejdź do katalogu:

```bash
cd /share/Container/zakupy/infra
```

3. Przy pierwszym wdrożeniu albo po zmianach konfiguracji przygotuj i uzupełnij `qnap.backend.env` na bazie [infra/qnap.backend.env.example](infra/qnap.backend.env.example).

Najważniejsze pola do ustawienia:
- `POSTGRES_PASSWORD`
- `DATABASE_URL`
- `JWT_SECRET`
- `BACKEND_IMAGE`
- ustawienia SMTP

4. Uruchom deployment:

```bash
sh scripts/deploy-backend.sh
```

Ten skrypt używa `qnap.backend.env` oraz `docker-compose.qnap.yml` i podnosi backend, PostgreSQL i Caddy.

## Aktualizacja aplikacji mobilnej

Na ten moment backend na QNAP jest dostępny pod:

```text
http://100.113.187.63
```

Przed buildem lub instalacją aplikacji ustaw ten adres przez `--dart-define=API_BASE_URL=...`.

### Android

Na podłączonym urządzeniu albo emulatorze:

```bash
cd mobile
flutter pub get
flutter run --release -d <android-device-id> --dart-define=API_BASE_URL=http://100.113.187.63
```

Jeśli chcesz tylko zbudować paczkę:

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=http://100.113.187.63
```

### iPhone

Na iPhonie albo w symulatorze:

```bash
cd mobile
flutter pub get
flutter run --release -d <ios-device-id> --dart-define=API_BASE_URL=http://100.113.187.63
```

Jeśli potrzebujesz samego buildu:

```bash
cd mobile
flutter build ios --release --dart-define=API_BASE_URL=http://100.113.187.63
```

Uwaga dla iPhone'a:
- obecna konfiguracja iOS nie ma wyjątku ATS dla czystego `http`
- na fizycznym iPhonie bezpieczniej używać adresu HTTPS przez Caddy albo Tailscale
- `http://100.113.187.63` jest w praktyce najpewniejsze dla Androida i lokalnych testów developerskich

## Najbliższe kroki

1. Dopięcie pełnego testowania end-to-end na dwóch realnych urządzeniach.
2. Wyczyszczenie UX po wspólnym użyciu z drugą osobą.
3. Rozszerzenie mobile o zarządzanie listami poza tworzeniem i współdzieleniem, jeśli okaże się to potrzebne w codziennym użyciu.
