import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_action.dart';

class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;
  
  Locale _locale = const Locale('ko'); // Default to Korean
  
  final Map<AppAction, LogicalKeyboardKey> _keyBindings = {
    AppAction.nextImage: LogicalKeyboardKey.arrowRight,
    AppAction.prevImage: LogicalKeyboardKey.arrowLeft,
    AppAction.delete: LogicalKeyboardKey.delete,
    AppAction.undo: LogicalKeyboardKey.keyZ,
    AppAction.restore: LogicalKeyboardKey.keyR,
  };

  SettingsProvider() {
    _loadSettings();
  }

  Locale get locale => _locale;
  Map<AppAction, LogicalKeyboardKey> get keyBindings => _keyBindings;

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load Locale
    final langCode = _prefs?.getString('locale_code');
    if (langCode != null) {
      _locale = Locale(langCode);
    }
    
    // Load KeyBindings
    for (var action in AppAction.values) {
      final keyId = _prefs?.getInt('key_binding_${action.index}');
      if (keyId != null) {
        final key = LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(keyId);
        _keyBindings[action] = key;
      }
    }
    notifyListeners();
  }

  Future<void> changeLocale(Locale locale) async {
    _locale = locale;
    await _prefs?.setString('locale_code', locale.languageCode);
    notifyListeners();
  }

  Future<void> updateKeyBinding(AppAction action, LogicalKeyboardKey key) async {
    _keyBindings[action] = key;
    await _prefs?.setInt('key_binding_${action.index}', key.keyId);
    notifyListeners();
  }
}
