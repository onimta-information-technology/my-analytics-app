
import 'package:shared_preferences/shared_preferences.dart';

class CurrentChatState {
  static final CurrentChatState _instance = CurrentChatState._internal();
  factory CurrentChatState() => _instance;
  CurrentChatState._internal();

  String? _currentChatId;

  // ⭐ IMPORTANT: Use "flutter." prefix for iOS compatibility
  static const String _storageKey = 'current_chat_id';

  Future<void> setCurrentChat(String? chatId) async {
    _currentChatId = chatId;
    print('📱 Flutter: Setting current chat to: $_currentChatId');
    
    // Save to SharedPreferences (becomes UserDefaults on iOS)
    final prefs = await SharedPreferences.getInstance();
    if (chatId != null && chatId.isNotEmpty) {
      await prefs.setString(_storageKey, chatId);
      print('✅ Saved to SharedPreferences: $_storageKey = $chatId');
    } else {
      await prefs.remove(_storageKey);
      print('🗑️ Removed from SharedPreferences: $_storageKey');
    }
  }

  String? getCurrentChat() {
    return _currentChatId;
  }

  bool isCurrentChat(String? chatId) {
    if (chatId == null || _currentChatId == null) return false;
    final match = chatId == _currentChatId;
    print('🔍 Checking if current chat: $chatId == $_currentChatId ? $match');
    return match;
  }

  Future<void> clearCurrentChat() async {
    print('📱 Flutter: Clearing current chat: $_currentChatId');
    _currentChatId = null;
    
    // Remove from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    print('✅ Cleared from SharedPreferences');
  }
}