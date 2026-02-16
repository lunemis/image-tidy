
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import '../../providers/image_provider.dart' as img_prov;

class ExplorerSidebar extends StatefulWidget {
  const ExplorerSidebar({super.key});

  @override
  State<ExplorerSidebar> createState() => _ExplorerSidebarState();
}

class _ExplorerSidebarState extends State<ExplorerSidebar> {
  final ScrollController _scrollController = ScrollController();
  
  // Caching grouping to avoid re-looping every frame
  Map<String, List<String>> _groupedImages = {};
  List<String>? _lastImagesRef;
  
  // Layout Constants
  static const double _folderHeaderHeight = 40.0;
  static const double _fileItemHeight = 28.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent();
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateGrouping(List<String> images) {
    if (identical(images, _lastImagesRef)) return;
    
    _groupedImages.clear();
    // LinkedHashMap preserves insertion order, which usually matches file scan order
    for (var img in images) {
      final parent = path.dirname(img);
      _groupedImages.putIfAbsent(parent, () => []).add(img);
    }
    _lastImagesRef = images;
  }

  void _scrollToCurrent() {
    if (!mounted) return;
    final provider = context.read<img_prov.ImageProvider>();
    final currentImage = provider.currentImage;
    if (currentImage == null) return;
    if (_groupedImages.isEmpty) return;
    if (!_scrollController.hasClients) return;

    final currentFolder = path.dirname(currentImage);
    
    // Calculate offset
    // 1. Height of all preceding folders (collapsed)
    double offset = 0.0;
    bool found = false;
    
    for (var folder in _groupedImages.keys) {
      if (folder == currentFolder) {
        // 2. Add height of preceding files in current folder
        offset += _folderHeaderHeight; // Header of current folder
        final imagesInFolder = _groupedImages[folder]!;
        final imageIndex = imagesInFolder.indexOf(currentImage);
        if (imageIndex != -1) {
          offset += imageIndex * _fileItemHeight;
        }
        found = true;
        break;
      } else {
        offset += _folderHeaderHeight;
      }
    }
    
    if (found) {
      // Center the item in the viewport if possible
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset = offset - (viewportHeight / 2) + (_fileItemHeight / 2);
      
      // Clamp
      final maxScroll = _scrollController.position.maxScrollExtent;
      final clampedOffset = targetOffset.clamp(0.0, maxScroll);
      
      _scrollController.jumpTo(clampedOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<img_prov.ImageProvider>();
    final images = provider.images;
    
    _updateGrouping(images);
    
    // Identify current folder for expansion
    final currentImage = provider.currentImage;
    final currentFullFolder = currentImage != null ? path.dirname(currentImage) : null;

    final folders = _groupedImages.keys.toList();

    return Container(
      width: 280, // Slightly wider for hierarchy
      color: Colors.grey[900],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.grey[850],
            width: double.infinity,
            child: const Text(
              "Explorer",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: images.isEmpty
                ? const Center(child: Text("No images", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      final folderPath = folders[index];
                      final isCurrentFolder = folderPath == currentFullFolder;
                      final folderName = path.basename(folderPath);
                      final folderImages = _groupedImages[folderPath]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Folder Header
                          Container(
                            height: _folderHeaderHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            color: isCurrentFolder ? Colors.grey[800] : Colors.transparent,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  isCurrentFolder ? Icons.folder_open : Icons.folder,
                                  size: 18,
                                  color: isCurrentFolder ? Colors.amber : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    folderName,
                                    style: TextStyle(
                                      color: isCurrentFolder ? Colors.white : Colors.grey[400],
                                      fontWeight: isCurrentFolder ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCurrentFolder)
                                  Text(
                                    "${folderImages.length}",
                                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                  ),
                              ],
                            ),
                          ),
                          
                          // File List (Only if current folder)
                          if (isCurrentFolder)
                            ...folderImages.map((img) {
                              final isSelected = img == currentImage;
                              return InkWell(
                                onTap: () {
                                  // Find global index
                                  // Since 'images' list in provider is flat and sorted essentially same way 
                                  // (assuming scan order preserved), we can use indexOf
                                  final globalIndex = images.indexOf(img);
                                  if (globalIndex != -1) {
                                    provider.jumpTo(globalIndex);
                                  }
                                },
                                child: Container(
                                  height: _fileItemHeight,
                                  padding: const EdgeInsets.only(left: 36.0, right: 8.0),
                                  color: isSelected ? Colors.blue.withOpacity(0.3) : null,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    path.basename(img),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.grey[400],
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
