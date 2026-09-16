class CurrentChatState {
  static final CurrentChatState _instance = CurrentChatState._internal();
  factory CurrentChatState() => _instance;
  CurrentChatState._internal();

  String? _currentChatId;

  /// The screen that set [_currentChatId]. A chat closed behind a newly
  /// opened one is disposed after the new one has registered, so its clear
  /// must not wipe the newer chat.
  Object? _owner;

  // Set the current open chat
  void setCurrentChat(String? chatId, {Object? owner}) {
    _currentChatId = chatId;
    _owner = owner;
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

  // Clear the current chat. With [owner], only if that screen still owns it.
  void clearCurrentChat({Object? owner}) {
    if (owner != null && !identical(owner, _owner)) return;
    _currentChatId = null;
    _owner = null;
  }
}
