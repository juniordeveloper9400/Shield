# SHIELD

SHIELD is a Flutter health-commerce member app backed by Neon Postgres, with a separate React/Vite operations console in `shieldweb/`.

## Start here

- [Documentation index](docs/README.md)
- [Architecture](docs/architecture.md)
- [Setup](docs/setup.md)
- [Development workflow](docs/development.md)
- [Database and backend](docs/database.md)
- [Admin console](docs/admin-console.md)
- [Testing](docs/testing.md)
- [Deployment](docs/deployment.md)
- [Security](docs/security.md)
- [Troubleshooting](docs/troubleshooting.md)

## Quick commands

```powershell
flutter pub get
flutter analyze
flutter test -j 2
flutter run
```

For the admin console:

```powershell
Set-Location shieldweb
npm install
npm run dev
```

Do not commit `.env`, generated Neon secret files, Firebase service-account credentials, passwords, or signing keys.
