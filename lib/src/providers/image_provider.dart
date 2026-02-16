import 'dart:io';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import '../services/file_service.dart';

enum ViewMode { normal, trash }

class ImageProvider extends ChangeNotifier {
  final FileService _fileService = FileService();
  
  ViewMode _viewMode = ViewMode.normal;
  List<String> _normalImages = [];
  List<String> _trashImages = [];
  
  // Current active list based on mode (internal helper, but we need index mapping)
  // To keep existing code working, let's make `_images` a getter?
  // But `_images` was a field used extensively.
  // Refactor: Rename internal storage to respective lists.
  // Expose `images` getter.
  
  // Since I cannot rename all usages easily in one block without viewing whole file, 
  // I will make `_images` the "current list" and maybe swap content on toggle?
  // Swapping content is dangerous if references exist.
  // Better: `List<String> get images => _viewMode == ViewMode.normal ? _normalImages : _trashImages;`
  // And remove `List<String> _images = [];` field.
  // We need to fix `_currentIndex` when switching.
  
  // Stored active list (copy) or direct reference?
  // Let's use direct lists.
  
  int _currentIndex = -1;
  bool _isLoading = false;
  
  // History for Undo: Stores (originalPath, trashPath, originalIndex)
  final ListQueue<_TrashAction> _history = ListQueue<_TrashAction>();
  
  Directory? _currentRoot; // Keep track of root to rescan

  ViewMode get viewMode => _viewMode;
  List<String> get images => _viewMode == ViewMode.normal ? _normalImages : _trashImages;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;


  
  String? get currentImage => _currentIndex >= 0 && _currentIndex < _images.length ? _images[_currentIndex] : null;

  // Pre-fetching helpers
  String? get nextImagePreview => (_currentIndex + 1 < _images.length) ? _images[_currentIndex + 1] : null;
  String? get prevImagePreview => (_currentIndex - 1 >= 0) ? _images[_currentIndex - 1] : null;

  // Folder boundary info
  String? get currentFolder => currentImage != null ? path.basename(path.dirname(currentImage!)) : null;

  // Internal alias for compatibility
  List<String> get _images => _viewMode == ViewMode.normal ? _normalImages : _trashImages;

  Future<void> pickAndScanDirectory() async {
    final dirPath = await _fileService.pickDirectory();
    if (dirPath == null) return;
    final dir = Directory(dirPath);
    _currentRoot = dir;

    _isLoading = true;
    notifyListeners();

    try {
      _normalImages = await _fileService.scanDirectory(dir, isTrashMode: false);
      _trashImages = await _fileService.scanDirectory(dir, isTrashMode: true);
      
      _viewMode = ViewMode.normal;
      
      if (_normalImages.isNotEmpty) {
        _currentIndex = 0;
      } else {
        _currentIndex = -1;
      }
      _history.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleViewMode() {
    _viewMode = _viewMode == ViewMode.normal ? ViewMode.trash : ViewMode.normal;
    if (_images.isNotEmpty) {
      _currentIndex = 0;
    } else {
      _currentIndex = -1;
    }
    notifyListeners();
  }

  Future<void> permanentDeleteCurrent() async {
    if (currentImage == null || _isDeleting) return;
    if (_viewMode != ViewMode.trash) return; // Safegaurd

    _isDeleting = true;
    final targetPath = currentImage!;
    final targetIndex = _currentIndex;

    try {
      await _fileService.deletePermanently(targetPath);
      
      // Remove from trash list
      if (targetIndex < _trashImages.length && _trashImages[targetIndex] == targetPath) {
         _trashImages.removeAt(targetIndex);
      } else {
         _trashImages.remove(targetPath);
      }

      // Adjust index
      if (_trashImages.isEmpty) {
        _currentIndex = -1;
      } else if (_currentIndex >= _trashImages.length) {
        _currentIndex = _trashImages.length - 1;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error permanently deleting: $e");
    } finally {
      _isDeleting = false;
    }
  }

  Future<void> restoreCurrent() async {
    if (currentImage == null || _isDeleting) return;
    if (_viewMode != ViewMode.trash) return;

    _isDeleting = true;
    final trashPath = currentImage!;
    final targetIndex = _currentIndex;
    
    // Infer original path: Parent/_Trash/File -> Parent/File
    final trashDir = path.dirname(trashPath); // .../_Trash
    final parentDir = path.dirname(trashDir); // .../
    final filename = path.basename(trashPath);
    final originalPath = path.join(parentDir, filename);

    try {
      await _fileService.restoreFromTrash(trashPath, originalPath);
      
      // Update Lists
      // Remove from Trash
      if (targetIndex < _trashImages.length && _trashImages[targetIndex] == trashPath) {
         _trashImages.removeAt(targetIndex);
      } else {
         _trashImages.remove(trashPath);
      }
      
      // Add to Normal (and sort?)
      // For simplicity, just add to end or simplistic insert.
      // Re-sorting might be expensive.
      _normalImages.add(originalPath);
      _normalImages.sort((a,b) => a.compareTo(b));

      // Adjust Trash Index
      if (_trashImages.isEmpty) {
        _currentIndex = -1;
      } else if (_currentIndex >= _trashImages.length) {
        _currentIndex = _trashImages.length - 1;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error restoring: $e");
    } finally {
      _isDeleting = false;
    }
  }
  
  Future<void> cleanupEmptyFolders() async {
    if (_currentRoot == null) return;
    await _fileService.deleteEmptyFolders(_currentRoot!);
    // Potentially rescan?
    // Empty folders don't affect image lists, so no rescan needed strictly.
    notifyListeners();
  }


  void nextImage() {
    if (_images.isEmpty) return;
    if (_currentIndex < _images.length - 1) {
      // Check folder change
      // final currentFolder = path.dirname(_images[_currentIndex]);
      // final nextFolder = path.dirname(_images[_currentIndex + 1]);
      
      _currentIndex++;
      notifyListeners();
      
      // Notice: In a real Provider, we might use a callback or stream to notify UI about folder changes for Toasts.
      // But for simplicity, the UI can listen to 'currentFolder' changes if needed.
    }
  }

  void prevImage() {
    if (_images.isEmpty) return;
    if (_currentIndex > 0) {
      _currentIndex--;
      notifyListeners();
    }
  }

  void jumpTo(int index) {
    if (index >= 0 && index < _images.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  bool _isDeleting = false;

  Future<void> deleteCurrent() async {
    if (_viewMode == ViewMode.trash) {
      await permanentDeleteCurrent();
      return;
    }

    if (currentImage == null || _isDeleting) return;

    _isDeleting = true;
    final targetPath = currentImage!;
    // We store the specific string, because index might change if we allowed concurrent ops (we don't now).
    final targetIndex = _currentIndex;

    try {
      final trashPath = await _fileService.moveToTrash(targetPath);
      
      // Add to undo history
      _history.addLast(_TrashAction(
        originalPath: targetPath, 
        trashPath: trashPath,
        originalIndex: targetIndex
      ));

      // Remove from list
      // We must be careful if the list changed, but with _isDeleting locking, it shouldn't for this simple app.
      if (targetIndex < _normalImages.length && _normalImages[targetIndex] == targetPath) {
         _normalImages.removeAt(targetIndex);
      } else {
         // Fallback: search for path
         _normalImages.remove(targetPath);
      }
      
      // Add to Trash List
      _trashImages.add(trashPath);
      _trashImages.sort((a,b) => a.compareTo(b));

      // Adjust index
      if (_normalImages.isEmpty) {
        _currentIndex = -1;
      } else if (_currentIndex >= _normalImages.length) {
        _currentIndex = _normalImages.length - 1;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint("Error moving to trash: $e");
    } finally {
      _isDeleting = false;
    }
  }

  Future<void> undo() async {
    if (_history.isEmpty) return;

    final action = _history.removeLast();
    try {
      await _fileService.restoreFromTrash(action.trashPath, action.originalPath);
      
      // Restore to list (Normal)
      if (action.originalIndex <= _normalImages.length) {
        _normalImages.insert(action.originalIndex, action.originalPath);
      } else {
        _normalImages.add(action.originalPath);
      }
      
      // Remove from Trash List
      _trashImages.remove(action.trashPath);

      // Navigate back to restored image if in normal mode
      if (_viewMode == ViewMode.normal) {
        _currentIndex = action.originalIndex;
      } else {
        // Adjust trash index if needed
        if (_currentIndex >= _trashImages.length) {
            _currentIndex = _trashImages.length - 1;
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint("Error restoring from trash: $e");
    }
  }
}

class _TrashAction {
  final String originalPath;
  final String trashPath;
  final int originalIndex;

  _TrashAction({
    required this.originalPath,
    required this.trashPath,
    required this.originalIndex,
  });
}
