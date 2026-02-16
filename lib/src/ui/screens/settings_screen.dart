import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../models/app_action.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        backgroundColor: Colors.grey[900],
      ),
      body: ListView(
        children: [
          // Language Section
          _buildSectionHeader(context, l10n.languageLabel),
          ListTile(
            title: Text(l10n.languageLabel),
            trailing: DropdownButton<String>(
              value: settings.locale.languageCode,
              dropdownColor: Colors.grey[800],
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ko', child: Text('한국어')),
              ],
              onChanged: (value) {
                if (value != null) {
                  settings.changeLocale(Locale(value));
                }
              },
            ),
          ),
          const Divider(),

          // Shortcuts Section
          _buildSectionHeader(context, l10n.shortcutsLabel),
          ...AppAction.values.map((action) {
            return ListTile(
              title: Text(_getActionLabel(l10n, action)),
              trailing: Chip(
                label: Text(_getKeyLabel(settings.keyBindings[action])),
                backgroundColor: Colors.grey[800],
              ),
              onTap: () => _showKeyBindingDialog(context, settings, action),
            );
          }),
          
          const Divider(),
          
          // About Section
          _buildSectionHeader(context, l10n.aboutLabel),
          ListTile(
            title: const Text("ImageTidy"),
            subtitle: const Text("Version 1.0.0"),
            leading: const Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getActionLabel(AppLocalizations l10n, AppAction action) {
    switch (action) {
      case AppAction.nextImage: return l10n.shortcutNextImage;
      case AppAction.prevImage: return l10n.shortcutPrevImage;
      case AppAction.delete: return l10n.shortcutDelete;
      case AppAction.undo: return l10n.shortcutUndo;
      case AppAction.restore: return l10n.shortcutRestore;
    }
  }

  String _getKeyLabel(LogicalKeyboardKey? key) {
    if (key == null) return "None";
    // Usually show debugName or simple name
    return key.keyLabel; 
  }

  void _showKeyBindingDialog(BuildContext context, SettingsProvider settings, AppAction action) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_getActionLabel(l10n, action)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.pressKeyToBind),
              const SizedBox(height: 20),
              // Capturing key press inside Dialog is tricky because Focus might be elsewhere.
              // Focus widget is needed.
              Focus(
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.escape) {
                      Navigator.of(context).pop();
                      return KeyEventResult.handled;
                    }
                    settings.updateKeyBinding(action, event.logicalKey);
                    Navigator.of(context).pop();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("Listening...", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }
}
