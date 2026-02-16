# ImageTidy PRD

## 1. Project Overview
Create a desktop application named "ImageTidy".
The primary goal is to allow users to quickly scan through a folder of images and "cull" (delete/move) unwanted photos using keyboard shortcuts with zero latency.

## 2. Technical Stack & Dependencies
- **Framework**: Flutter (Dart)
- **Target OS**: Windows 10/11 (Primary), Android (Secondary/Future)
- **Key Packages**:
    - `file_picker`: For selecting the root directory.
    - `path`: For file path manipulation.
    - `window_manager` (Optional): If window size control is needed.

## 3. Product Requirements
### A. Navigation & Scanning
- **Input**: User selects a Root Folder via a dialog.
- **Scanning**:
    - Recursively scan the root folder and all subfolders.
    - Filter for JPG, PNG, JPEG files only.
    - Sort all found images by file path (mimicking directory structure order).
    - Treat the result as a single flat list of images for continuous navigation.
- **Auto-Traversal**: When the user reaches the last image of Folder A and presses "Next", automatically show the first image of Folder B.
- **Toast Notification**: Show "Folder Changed: [Folder Name]" when crossing folder boundaries.

### B. Image Viewer (Performance Critical)
- **Pre-fetching**: Must implement logic to pre-cache the Previous (1) and Next (2-3) images into memory to ensure 0.1s transition latency.
- **Gapless Playback**: Use `gaplessPlayback: true` to prevent flickering.
- **Display**: Fit image to screen while maintaining aspect ratio.

### C. UI Layout
- **Main View**: Center the current image (largest area).
- **Side Previews**:
    - Left Edge: Small, semi-transparent thumbnail of the Previous image.
    - Right Edge: Small, semi-transparent thumbnail of the Next image.
- **Overlay Info**: Display "Current Index / Total", "Folder Name", and "File Name" at the top (semi-transparent background).

### D. Culling Logic (The Core Feature)
- **Action**: When the "Delete" key is pressed:
    - Do NOT show a confirmation dialog.
    - Move the current file to a subfolder named `_Trash` located inside the current file's parent folder. (e.g., `D:/Photos/2023/_Trash/image.jpg`).
    - If `_Trash` does not exist, create it.
- **Undo**:
    - Store actions in a Stack.
    - On `Ctrl+Z`, move the file back from `_Trash` to its original location and navigate back to that image.

### E. Keyboard Shortcuts (No Mouse Required)
- **Left Arrow / A**: Previous Image
- **Right Arrow / D**: Next Image
- **Down Arrow / Del / S**: Move to Trash (Next image automatically loads)
- **Ctrl + Z**: Undo last trash action

## 4. Implementation Guidelines
- **Single File Structure**: If possible, keep the main logic in `lib/main.dart` but organize classes cleanly (e.g., `ImageController`, `CullingPage`).
- **Error Handling**: Handle cases where the file might be locked or missing.
- **Performance**: Do not block the UI thread during file scanning or moving. Use `async/await` properly.
- **UI Theme**: Use a Dark Theme (black background) to focus on the photos.
