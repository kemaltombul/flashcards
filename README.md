# 🇬🇧 English Flashcards - Word Learning App

A modern, dark-themed Flutter application designed to help users learn English vocabulary using flashcards. The app supports creating collections, adding words with definitions and examples, and testing knowledge through study and game modes.

## ✨ Features

-   **🗂 Manage Collections:** Create and organize multiple vocabulary sets (e.g., "A1 Verbs", "Business English").
-   **📝 Word Management:** Add new words with:
    -   English Word & Definition
    -   Turkish Meaning (or your native language)
    -   Example Sentences
-   **📚 Study Mode:** Flip cards to reveal meanings and learn at your own pace.
-   **⏳ Game Mode:** Test yourself with a timer! Meaning is hidden until the timer runs out or you feel ready.
-   **🎨 Modern UI:** Sleek dark mode with glassmorphism effects and fluid animations.
-   **💾 data Persistence:** Uses SQLite (`sqflite`) for local storage.
-   **📤 Import/Export:** Backup and share your collections using JSON.

## 📸 Screenshots

| Home Page | Card View | Add Word |
|:---------:|:---------:|:--------:|
| ![Home Page](assets/screenshots/home.png) | ![Card View](assets/screenshots/card.png) | ![Add Word](assets/screenshots/add_word.png) |

## 🛠 Tech Stack

-   **Framework:** [Flutter](https://flutter.dev)
-   **Language:** Dart
-   **Database:** `sqflite` (SQLite)
-   **State Management:** `setState` (Simple & Effective)
-   **Other Packages:** `path_provider`, `file_picker`, `share_plus`, `url_launcher`

## 🚀 Getting Started

### Prerequisites

-   Flutter SDK installed ([Installation Guide](https://flutter.dev/docs/get-started/install))
-   An IDE (VS Code, Android Studio, or IntelliJ)

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/kemaltombul/flashcards.git
    cd flashcards
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    ```bash
    flutter run
    ```

### Generating App Icons

If you want to update or regenerate the app icons, run:
```bash
dart run flutter_launcher_icons
```

## 📂 Project Structure

-   `lib/models/`: Data models (`Word`, `Collection`).
-   `lib/screens/`: UI pages (`HomePage`, `CardPage`, `AddWordPage`, etc.).
-   `lib/services/`: Database and logic services (`DatabaseService`).
-   `assets/`: Images and initial data.

## 🤝 Contributing

Contributions are welcome! If you find a bug or want to add a feature, please feel free to open an issue or submit a pull request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
