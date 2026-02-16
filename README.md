# ImageTidy

**ImageTidy** is a high-performance image organization tool built with Flutter for Desktop. It is designed to help users quickly review, categorize, and clean up large collections of images with ease.

![App Screenshot](https://via.placeholder.com/800x450?text=ImageTidy+Screenshot) 
> *Screenshots to be added*

---

## ✨ Features

- **🚀 High Performance**: optimized for fast image loading and smooth navigation with pre-fetching.
- **📂 Folder Tree Navigation**: Collapsible sidebar to easily browse nested directories.
- **⌨️ Keyboard Centric**:
    - `Arrows` / `WASD`: Navigate images.
    - `Delete`: Move to Trash.
    - `Ctrl+Z`: Undo last action.
- **🗑️ Trash Review Mode**:
    - Safely review deleted items before permanent deletion.
    - `Restore` functionality.
    - `Cleanup Empty Folders` to keep your directories clean.
- **🌍 Internationalization (i18n)**: Supports **English** and **Korean (한국어)**.
- **⚙️ Customizable Settings**:
    - Change language.
    - **Custom Keybindings**: Remap shortcuts to your preference.

## 🛠️ Installation

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
- **Windows**: Visual Studio 2022 with "Desktop development with C++" workload.

### Build & Run
```bash
# 1. Clone the repository
git clone https://github.com/yourusername/imageTidy.git
cd imageTidy

# 2. Install dependencies
flutter pub get

# 3. Generate localization files
flutter gen-l10n

# 4. Run the app
flutter run -d windows
```

## 📖 Usage

1.  **Open Folder**: Click "Open Folder" to select the root directory containing your images.
2.  **Review**: Use `Right`/`Left` arrow keys to browse.
3.  **Organize**:
    - Press `Delete` to move unwanted images to `_Trash` folder.
    - Images are **not** deleted immediately.
4.  **Trash Review**:
    - Click the **Trash Icon** in the toolbar to enter Trash Mode.
    - Review images in the `_Trash` folder.
    - Press `Delete` again to **permanently delete**.
    - Press `R` to **Restore** to original location.
5.  **Settings**: Click the **Gear Icon** to change language or shortcuts.

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
