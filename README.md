# Sonar Notes 🎙️📝

**Sonar Notes** is a cross-platform application (Android, iOS, macOS, Windows, Linux, Web) designed for high-fidelity audio recording, automated speech-to-text transcription, and intelligent note organization.

---

## 🚀 Key Features & Stack

- **Audio Recording & Playback**: Powered by [`record`](https://pub.dev/packages/record) and [`audioplayers`](https://pub.dev/packages/audioplayers) for clean multi-format capture and playback.
- **Speech-to-Text**: Real-time and post-recording transcription utilizing [`speech_to_text`](https://pub.dev/packages/speech_to_text).
- **Local Persistence**: Fast and reliable local storage using [`sqflite`](https://pub.dev/packages/sqflite) and [`path_provider`](https://pub.dev/packages/path_provider).
- **State Management**: Reactive, testable state management built on [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod).
- **Modern UI & Motion**: Customized typography via [`google_fonts`](https://pub.dev/packages/google_fonts), vector assets via [`flutter_svg`](https://pub.dev/packages/flutter_svg), and smooth animations via [`lottie`](https://pub.dev/packages/lottie).

---

## 🏗️ Architecture & Project Structure

The project follows **Clean Architecture** principles structured by **Feature-First**:

```text
lib/
├── core/
│   ├── constants/    # Global constants, keys, and asset definitions
│   ├── services/     # Low-level native & platform wrappers
│   ├── theme/        # Color schemes, typography, and styling
│   └── utils/        # Formatting, helpers, and extension methods
├── features/
│   ├── audio_recording/
│   │   ├── data/          # Data sources, repositories, and models
│   │   ├── domain/        # Use cases, entities, and repository interfaces
│   │   └── presentation/  # UI widgets, screens, and Riverpod providers
│   ├── transcription/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── notes/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── main.dart          # Application entry point with ProviderScope
```

---

## 🛠️ Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.20.0 or higher)
- [Dart SDK](https://dart.dev/get-started/sdk) (v3.0.0 or higher)
- Windows 10/11 with **Developer Mode** enabled (for Windows target) or Android Studio / Xcode (for mobile & desktop targets).

### Installation & Run

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd sonarNotes
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the application**:
   - **Windows Desktop**:
     ```bash
     flutter run -d windows
     ```
   - **Android**:
     ```bash
     flutter run -d <device-id>
     ```
   - **Web**:
     ```bash
     flutter run -d chrome
     ```

### Running Tests

Execute the automated widget and unit tests:
```bash
flutter test
```

---

## 📜 Agent Guidelines

System prompt directives for automated coding agents and contributors are located in [.antigravity/system_instructions.md](file:///.antigravity/system_instructions.md).
