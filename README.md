# no_model_farmer_app

# HPGM - Hive Performance & Growth Monitoring

HPGM (Honey Productivity, Guide and Monitor) is a Flutter application for beekeepers to track hive productivity, monitor bee activity, and manage apiaries.

## Features

- **Apiary Management**: Track and manage multiple apiaries and hives
- **Bee Activity Monitoring**: Analyze video to count bees entering and exiting hives
- **Foraging Analysis**: Analyze bee foraging patterns and efficiency
- **Environmental Monitoring**: Track temperature, humidity, and hive weight
- **PDF Reporting**: Generate bee foraging analysis reports
- **Inspection Records**: Keep hive inspection records
- **Recommendations**: Get recommendations based on hive performance
- **Dashboard**: View key metrics and performance indicators
- **Multi-platform**: Android, iOS, Web, Windows, Linux, and macOS

## Getting Started

### Prerequisites

- Flutter SDK 3.7.0 or higher
- Dart SDK 3.7.0 or higher
- Android Studio or VS Code with Flutter extensions
- Git

### Installation

```bash
git clone https://github.com/AyanMustafa/no_model_farmer_app.git
cd no_model_farmer_app
flutter pub get
flutter run
```

## Building

```bash
flutter build apk --release
flutter build web --release
flutter build windows --release
flutter build linux --release
flutter build macos --release
```

For iOS:

```bash
flutter build ios --release
```

## Testing

```bash
flutter test test/unit
```

The unit test report is documented in `docs/unit_tests.md`.
