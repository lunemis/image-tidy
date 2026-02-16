import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import '../../../l10n/app_localizations.dart';
import '../../providers/image_provider.dart' as img_prov;
import '../../providers/settings_provider.dart';
import '../../models/app_action.dart';
import '../widgets/explorer_sidebar.dart';
import 'settings_screen.dart';

enum DisplayMode { fit, stretch }

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final FocusNode _focusNode = FocusNode();
  final TransformationController _transformationController = TransformationController();
  String? _lastFolder;
  DisplayMode _displayMode = DisplayMode.fit;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    // Auto-focus and listen for folder changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      context.read<img_prov.ImageProvider>().addListener(_onProviderUpdate);
    });
    
    _transformationController.addListener(() {
      if (!mounted) return;
      setState(() {
        _currentScale = _transformationController.value.getMaxScaleOnAxis();
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformationController.dispose();
    context.read<img_prov.ImageProvider>().removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final provider = context.read<img_prov.ImageProvider>();
    final currentFolder = provider.currentFolder;

    if (_lastFolder != null && currentFolder != null && currentFolder != _lastFolder) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Folder Changed: $currentFolder"),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _lastFolder = currentFolder;
    
    // Optional: Reset zoom on image change? 
    // Usually image viewers keep zoom if it is "Lock Zoom", but here let's reset for simplicity 
    // unless user wants it preserved. Defaulting to reset to fit/stretch.
    // _transformationController.value = Matrix4.identity(); 
    // Actually, provider update happens on every notifyListeners() which includes pre-fetching updates etc.
    // We should only reset if the image INDEX changed.
    // We can track lastImage index in state if needed.
    // implementing checking:
    // ... logic omitted for brevity, let's keep zoom for now or let InteractiveViewer handle key changes.
    // Since we use ValueKey(provider.currentImage!), InteractiveViewer state will be lost/reset automatically!
    // So zoom resets on image change. Good.
  }

  void _handleKeyEvent(RawKeyEvent event, img_prov.ImageProvider provider, SettingsProvider settings) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      
      if (key == settings.keyBindings[AppAction.nextImage]) {
        provider.nextImage();
      } else if (key == settings.keyBindings[AppAction.prevImage]) {
        provider.prevImage();
      } else if (key == settings.keyBindings[AppAction.delete]) {
        provider.deleteCurrent();
      } else if (key == settings.keyBindings[AppAction.undo]) {
        provider.undo();
      } else if (key == settings.keyBindings[AppAction.restore]) {
        if (provider.viewMode == img_prov.ViewMode.trash) {
          provider.restoreCurrent();
        }
      }
    }
  }

  void _precacheNextImages(BuildContext context, img_prov.ImageProvider provider) {
    if (provider.nextImagePreview != null) {
      precacheImage(FileImage(File(provider.nextImagePreview!)), context);
    }
    if (provider.prevImagePreview != null) {
      precacheImage(FileImage(File(provider.prevImagePreview!)), context);
    }

    final nextIndex = provider.currentIndex + 1;
    if (nextIndex + 1 < provider.images.length) {
       precacheImage(FileImage(File(provider.images[nextIndex + 1])), context);
    } 
    if (nextIndex + 2 < provider.images.length) {
       precacheImage(FileImage(File(provider.images[nextIndex + 2])), context);
    }
  }

  Widget _buildToolbar() {
    final provider = context.watch<img_prov.ImageProvider>();
    final isTrashMode = provider.viewMode == img_prov.ViewMode.trash;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: 48,
      color: isTrashMode ? Colors.red[900]!.withOpacity(0.8) : Colors.grey[900], // Red tint for trash
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Trash Toggle
          IconButton(
            icon: Icon(isTrashMode ? Icons.delete : Icons.delete_outline, color: Colors.white),
            tooltip: isTrashMode ? l10n.exitTrashModeTooltip : l10n.enterTrashModeTooltip,
            onPressed: () {
               provider.toggleViewMode();
               _focusNode.requestFocus();
            },
          ),
          
          const VerticalDivider(width: 32, color: Colors.grey),
          
          // Display Mode
          Text(l10n.displayModeLabel, style: const TextStyle(color: Colors.white70)),
          const SizedBox(width: 8),
          ToggleButtons(
            isSelected: [_displayMode == DisplayMode.fit, _displayMode == DisplayMode.stretch],
            onPressed: (index) {
              setState(() {
                _displayMode = index == 0 ? DisplayMode.fit : DisplayMode.stretch;
                _transformationController.value = Matrix4.identity();
              });
              _focusNode.requestFocus();
            },
            color: Colors.white70,
            selectedColor: Colors.blue,
            fillColor: Colors.blue.withOpacity(0.2),
            borderColor: Colors.grey[700],
            selectedBorderColor: Colors.blue,
            borderRadius: BorderRadius.circular(4),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 60),
            children: [
              Text(l10n.displayFit),
              Text(l10n.displayStretch),
            ],
          ),
          
          const VerticalDivider(width: 32, color: Colors.grey),
          
          // Zoom
          Text(l10n.zoomLabel, style: const TextStyle(color: Colors.white70)),
          SizedBox(
            width: 150,
            child: Slider(
              value: _currentScale.clamp(0.5, 4.0),
              min: 0.5,
              max: 4.0,
              activeColor: Colors.blue,
              inactiveColor: Colors.grey[700],
              onChanged: (value) {
                setState(() {
                  _currentScale = value;
                  _transformationController.value = Matrix4.identity()..scale(value);
                });
              },
              onChangeEnd: (_) => _focusNode.requestFocus(), 
            ),
          ),
          SizedBox(
            width: 40,
            child: Text("${(_currentScale * 100).toInt()}%", style: const TextStyle(color: Colors.white70)),
          ),
          
          // Cleanup Button (Trash Mode Only)
          if (isTrashMode) ...[
             const VerticalDivider(width: 32, color: Colors.grey),
             TextButton.icon(
               icon: const Icon(Icons.folder_off, size: 16, color: Colors.white),
               label: Text(l10n.cleanupButtonLabel, style: const TextStyle(color: Colors.white)),
               style: TextButton.styleFrom(backgroundColor: Colors.red[700]),
               onPressed: () async {
                  await provider.cleanupEmptyFolders();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.cleanupDoneMessage))
                    );
                  }
                  _focusNode.requestFocus();
               },
             )
          ],

          // Settings Button
          const VerticalDivider(width: 32, color: Colors.grey),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: l10n.settingsTitle,
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _focusNode.requestFocus();
            },
          ),
          
          const Spacer(),
          // Help hint
          Text(
            isTrashMode ? l10n.helpTrash : l10n.helpNormal,
            style: const TextStyle(color: Colors.white30, fontSize: 12)
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<img_prov.ImageProvider>();
    
    // Trigger pre-caching
    _precacheNextImages(context, provider);

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) => _handleKeyEvent(event, context.read<img_prov.ImageProvider>(), context.read<SettingsProvider>()),
      autofocus: true,
      child: Scaffold(
        body: provider.isLoading 
            ? const Center(child: CircularProgressIndicator())
            : provider.images.isEmpty 
                ? Center(
                    child: ElevatedButton(
                      onPressed: () => provider.pickAndScanDirectory(),
                      child: const Text('Open Folder'),
                    ),
                  )
                : Row(
                    children: [
                      // Sidebar
                      const ExplorerSidebar(),
                      
                      // Main Content
                      Expanded(
                        child: Column(
                          children: [
                            // Toolbar
                            _buildToolbar(),

                            // Image Area
                            Expanded(
                              child: Stack(
                                children: [
                                  // Main Image
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black, 
                                      child: provider.currentImage != null 
                                          ? InteractiveViewer(
                                              transformationController: _transformationController,
                                              minScale: 0.5,
                                              maxScale: 4.0,
                                              child: SizedBox.expand(
                                                child: Image.file(
                                                  File(provider.currentImage!),
                                                  key: ValueKey(provider.currentImage!),
                                                  fit: _displayMode == DisplayMode.stretch ? BoxFit.fill : BoxFit.contain,
                                                  gaplessPlayback: true,
                                                  errorBuilder: (context, error, stackTrace) => const Center(
                                                    child: Icon(Icons.broken_image, size: 100, color: Colors.grey),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : const Center(child: Text("No Image")),
                                    ),
                                  ),
                                  
                                  // Previous Thumbnail (Left) - Keep overlay logic same
                                  if (provider.prevImagePreview != null)
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: 100,
                                      child: IgnorePointer(
                                        child: Opacity(
                                          opacity: 0.3, 
                                          child: Image.file(
                                            File(provider.prevImagePreview!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => const SizedBox(),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Next Thumbnail (Right)
                                  if (provider.nextImagePreview != null)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: 100,
                                      child: IgnorePointer(
                                        child: Opacity(
                                          opacity: 0.3,
                                          child: Image.file(
                                            File(provider.nextImagePreview!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => const SizedBox(),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Overlay Info (Moved down slightly to not overlap toolbar if needed, but toolbar is separate now so top: 20 is fine)
                                  Positioned(
                                    top: 20,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "${provider.currentIndex + 1} / ${provider.images.length}",
                                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                            if (provider.currentImage != null)
                                              Text(
                                                "${provider.currentFolder} / ${path.basename(provider.currentImage!)}",
                                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                textAlign: TextAlign.center,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
