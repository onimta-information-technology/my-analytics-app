class CurrentChatState {
  static final CurrentChatState _instance = CurrentChatState._internal();
  factory CurrentChatState() => _instance;
  CurrentChatState._internal();

  String? _currentChatId;

  // Set the current open chat
  void setCurrentChat(String? chatId) {
    _currentChatId = chatId;
    print('📱 Current chat set to: $_currentChatId');
  }

  // Get the current open chat
  String? getCurrentChat() {
    return _currentChatId;
  }

  // Check if a chat ID matches the current open chat
  bool isCurrentChat(String? chatId) {
    if (chatId == null || _currentChatId == null) return false;
    return chatId == _currentChatId;
  }

  // Clear the current chat
  void clearCurrentChat() {
    print('📱 Clearing current chat: $_currentChatId');
    _currentChatId = null;
  }
}
