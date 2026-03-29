# Zakupy

Prywatna aplikacja zakupowa dla dwóch użytkowników. Projekt celuje w prosty, utrzymywalny MVP:
- aplikacja mobilna we Flutterze dla Androida i iPhone
- backend REST w Node.js, Fastify i TypeScript
- PostgreSQL jako źródło prawdy
- wdrożenie na domowym VM przez Docker Compose
- dostęp prywatny przez Tailscale i reverse proxy Caddy

## Struktura repozytorium

```text
.
├── backend/   # API Fastify, Prisma, TypeScript
├── docs/      # architektura, plan MVP, API, notatki operacyjne
├── infra/     # docker-compose, Caddyfile, deployment notes
└── mobile/    # starter aplikacji Flutter
```

## Szybki start

### 1. Lokalny test na Macu przez Docker Desktop

Jeśli nie masz lokalnego PostgreSQL, użyj Dockera. To jest teraz domyślna ścieżka dla developmentu lokalnego.

```bash
cd infra
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
docker compose up --build -d
```

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

`mobile/` zawiera starter struktury Flutter, ale nie jest wygenerowany przez `flutter create`, bo `flutter` nie jest dostępny w tym środowisku. Gdy będziesz mieć Flutter SDK lokalnie:

```bash
cd mobile
flutter create .
```

Po tym zachowaj istniejący układ `lib/` i dopasuj wygenerowane pliki platformowe.

### 4. Flutter i backend razem

Najprostszy lokalny flow:

1. W jednym terminalu uruchom `docker compose up --build -d postgres backend` w [infra/](/Users/piotr/sandbox/Zakupy/infra).
2. Sprawdź `curl http://localhost:3000/health`.
3. Wyślij `POST /auth/register`, żeby potwierdzić zapis do Postgresa.
4. W [mobile/](/Users/piotr/sandbox/Zakupy/mobile) wykonaj `flutter create .`, potem `flutter pub get`.
5. Uruchom `flutter run` na simulatorze iOS albo emulatorze Android.

## MVP

Zakres pierwszej wersji:
- rejestracja i logowanie
- tworzenie list zakupowych
- współdzielenie list z drugim użytkownikiem
- dodawanie, edycja, usuwanie i odhaczanie pozycji
- prosty sync oparty o odświeżanie danych po zapisie

## Najbliższe kroki

1. Zainstalować zależności backendu i wykonać pierwszą migrację Prisma.
2. Dokończyć moduł auth z Argon2 i JWT.
3. Dodać CRUD list, członkostwa i pozycji.
4. Wygenerować pełny projekt Flutter przez `flutter create .` w `mobile/`.
5. Spiąć mobile z backendem przez REST.
