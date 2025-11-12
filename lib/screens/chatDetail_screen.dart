import 'dart:async';
import 'dart:io';
import 'package:ballys_reservation_app/components/badge_service.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/models/chat_message.dart';
import 'package:ballys_reservation_app/utils/current_chat_state.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';

class IndividualChatScreen extends StatefulWidget {
  final ChatContact contact;
  final Function(String)? onMessageSent;

  const IndividualChatScreen({
    super.key,
    required this.contact,
    this.onMessageSent,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _messageFocusNode = FocusNode();

  List<ChatMessage> _messages = [];
  String? _currentUserName;
  String? _selectedMessageId;
  bool _isLoadingMessages = false;

  // Optimization variables
  DateTime? _lastFetchTime;
  String? _lastMessageId;

  // Polling timer for read status updates
  Timer? _readStatusPollTimer;

  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CurrentChatState().setCurrentChat(widget.contact.chatUuid);
    _getCurrentUserName();
    _fetchMessagesFromApi();
    _setupForegroundMessageListener();
    _startReadStatusPolling();
    _messageFocusNode.addListener(_onFocusChange);

    // Clear badge when entering chat
    BadgeService().clearBadge();
  }

  @override
  void dispose() {
    _readStatusPollTimer?.cancel();
    _foregroundMessageSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    CurrentChatState().clearCurrentChat();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  // Start polling for read status updates every 3 seconds
  void _startReadStatusPolling() {
    _readStatusPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _fetchMessagesFromApi(silent: true, updateReadStatusOnly: true);
      }
    });
  }

  void _onFocusChange() {
    if (_messageFocusNode.hasFocus) {
      // Keyboard is opening, scroll to bottom after delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToBottom();
        }
      });
    }
  }

  void _setupForegroundMessageListener() {
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      final chatId =
          message.data['chatId'] ??
          message.data['chat_id'] ??
          message.data['ChatId'] ??
          message.data['Chat_Id'];
      final msgType = message.data['msg_type'] ?? message.data['type'];

      bool isChatMessage =
          msgType == '11' ||
          msgType == 'chat' ||
          message.data.containsKey('message') ||
          message.data.containsKey('Details');

      if (isChatMessage) {
        if (chatId == null ||
            chatId.isEmpty ||
            chatId == widget.contact.chatUuid) {
          _fetchMessagesFromApi(silent: true);
        }
      }
    });
  }

  Future<void> _getCurrentUserName() async {
    try {
      final userName = await StorageUtil.getUserName();
      setState(() {
        _currentUserName = userName;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _fetchMessagesFromApi({
    bool silent = false,
    bool updateReadStatusOnly = false,
  }) async {
    if (_isLoadingMessages && !silent) return;

    if (!silent && !updateReadStatusOnly) {
      setState(() {
        _isLoadingMessages = true;
      });
    }

    try {
      final chatId = widget.contact.chatUuid;
      final response = await FirebaseApiService.fetchMessages(chatId);
      final deviceId = await DeviceId.get();

      if (response['success'] == true && response['data'] != null) {
        final responseData = response['data'];

        if (responseData['success'] == true &&
            responseData['messages'] != null) {
          final List<dynamic> messagesJson = responseData['messages'];

          final List<ChatMessage> fetchedMessages = messagesJson
              .map((json) => ChatMessage.fromApiResponse(json, deviceId ?? ''))
              .toList();

          if (updateReadStatusOnly) {
            // Only update read status
            bool hasReadStatusChanged = false;

            for (int i = 0; i < _messages.length; i++) {
              final oldMessage = _messages[i];
              final newMessage = fetchedMessages.firstWhere(
                (msg) => msg.apiMessageId == oldMessage.apiMessageId,
                orElse: () => oldMessage,
              );

              if (oldMessage.isRead != newMessage.isRead) {
                hasReadStatusChanged = true;
                _messages[i] = newMessage;
              }
            }

            if (hasReadStatusChanged && mounted) {
              setState(() {});
            }
          } else {
            // Check if there are new messages
            final hadMessages = _messages.isNotEmpty;
            final messageCountChanged =
                _messages.length != fetchedMessages.length;

            setState(() {
              _messages = fetchedMessages;
              if (!silent) {
                _isLoadingMessages = false;
              }
            });

            await _markMessagesAsRead();

            // Only scroll on initial load or when explicitly refreshing
            if (!hadMessages || (!silent && messageCountChanged)) {
              // Small delay to ensure ListView is built
              await Future.delayed(const Duration(milliseconds: 100));
              _scrollToBottom();
            }
          }
        } else {
          if (!silent && !updateReadStatusOnly) {
            setState(() {
              _isLoadingMessages = false;
            });
          }
        }
      }
    } catch (e) {
      if (!silent && !updateReadStatusOnly) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      if (_currentUserName == null || _messages.isEmpty) return;

      final unreadMessageIds = _messages
          .where((msg) => !msg.isMe && msg.apiMessageId != null)
          .map((msg) => msg.apiMessageId!)
          .toList();

      if (unreadMessageIds.isEmpty) return;

      final response = await FirebaseApiService.markMessagesAsRead(
        widget.contact.chatUuid,
        unreadMessageIds,
      );

      if (response['success'] == true) {
        // Success
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _deleteMessageFromApi(String chatId, String messageId) async {
    try {
      // Use FirebaseApiService instead of manual HTTP call
      final response = await FirebaseApiService.softDeleteMessage(
        chatId,
        messageId,
      );

      if (response['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete message.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error deleting message. Please check your connection.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _sendMessageWithApi(
    String messageText,
    String localMessageId,
  ) async {
    if (_currentUserName == null) {
      return null;
    }

    try {
      // Use FirebaseApiService instead of manual HTTP call
      final response = await FirebaseApiService.sendMessage(
        recipientUuid: widget.contact.userUuid,
        message: messageText,
        title: _currentUserName!,
        body: messageText,
        chatId: widget.contact.chatUuid,
      );

      if (response['success'] == true && response['data'] != null) {
        final responseData = response['data'];
        if (responseData['success'] == true && responseData['data'] != null) {
          final messageId = responseData['data']['messageId'];
          final chatId = responseData['data']['chatId'];

          setState(() {
            final messageIndex = _messages.indexWhere(
              (msg) => msg.id == localMessageId,
            );
            if (messageIndex != -1) {
              _messages[messageIndex] = _messages[messageIndex].copyWith(
                apiMessageId: messageId,
                apiChatId: chatId,
                isRead: false, // Initially not read
              );
            }
          });

          return messageId;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error sending message. Please check your connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return null;
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      final messageText = _messageController.text.trim();
      final localMessageId = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();

      final message = ChatMessage(
        id: localMessageId,
        text: messageText,
        isMe: true,
        timestamp: now,
        isRead: false,
      );

      setState(() {
        _messages.add(message);
        _lastMessageId = localMessageId;
        _lastFetchTime = now;
      });

      _messageController.clear();
      // Scroll is automatic with reverse: true, but you can keep it for smoothness

      if (widget.onMessageSent != null) {
        widget.onMessageSent!(messageText);
      }

      final apiMessageId = await _sendMessageWithApi(
        messageText,
        localMessageId,
      );
    }
  }

  void _onCameraPressed() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        final localMessageId = DateTime.now().millisecondsSinceEpoch.toString();
        final message = ChatMessage(
          id: localMessageId,
          text: 'Photo',
          isMe: true,
          timestamp: DateTime.now(),
          filePath: photo.path,
          fileType: 'image',
          fileName: photo.name,
        );

        setState(() {
          _messages.add(message);
        });

        _scrollToBottom();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo captured successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onAttachFilePressed() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.insert_drive_file,
                  color: Colors.orange,
                ),
                title: const Text('Document'),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Cancel'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final localMessageId = DateTime.now().millisecondsSinceEpoch.toString();
        final message = ChatMessage(
          id: localMessageId,
          text: 'Image',
          isMe: true,
          timestamp: DateTime.now(),
          filePath: image.path,
          fileType: 'image',
          fileName: image.name,
        );

        setState(() {
          _messages.add(message);
        });

        _scrollToBottom();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image selected successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final localMessageId = DateTime.now().millisecondsSinceEpoch.toString();
        final message = ChatMessage(
          id: localMessageId,
          text: file.name,
          isMe: true,
          timestamp: DateTime.now(),
          filePath: file.path,
          fileType: 'document',
          fileName: file.name,
        );

        setState(() {
          _messages.add(message);
        });

        _scrollToBottom();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document "${file.name}" selected!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          0, // Scroll to 0 for reversed list
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }

  // NEW: Format date for separator
  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('d MMMM yyyy').format(date);
    }
  }

  // NEW: Check if we need to show date separator
  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;

    final currentMessage = _messages[index];
    final previousMessage = _messages[index - 1];

    final currentDate = DateTime(
      currentMessage.timestamp.year,
      currentMessage.timestamp.month,
      currentMessage.timestamp.day,
    );

    final previousDate = DateTime(
      previousMessage.timestamp.year,
      previousMessage.timestamp.month,
      previousMessage.timestamp.day,
    );

    return currentDate != previousDate;
  }

  void _deleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                final message = _messages.firstWhere(
                  (msg) => msg.id == messageId,
                );

                if (message.apiChatId != null && message.apiMessageId != null) {
                  await _deleteMessageFromApi(
                    message.apiChatId!,
                    message.apiMessageId!,
                  );
                }

                setState(() {
                  _messages.removeWhere((message) => message.id == messageId);
                  _selectedMessageId = null;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message deleted'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _onMessageLongPress(String messageId) {
    setState(() {
      _selectedMessageId = messageId;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMessageId = null;
    });
  }

  // NEW: Build date separator widget
  Widget _buildDateSeparator(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 236, 236, 226),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _formatDateSeparator(date),
          style: const TextStyle(
            color: Color.fromARGB(255, 2, 2, 2),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final isSelected = _selectedMessageId == message.id;

    return GestureDetector(
      onLongPress: () => _onMessageLongPress(message.id),
      onTap: _clearSelection,
      child: Container(
        color: isSelected ? Colors.grey.withOpacity(0.1) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: message.isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!message.isMe) ...[
                CircleAvatar(
                  backgroundColor: widget.contact.avatarColor,
                  radius: 15,
                  child: Text(
                    widget.contact.initials,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: message.isMe ? Colors.green : Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.fileType == 'image' &&
                          message.filePath != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(message.filePath!),
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            cacheHeight: 400, // ADD THIS for better performance
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (message.fileType == 'document' &&
                          message.fileName != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: message.isMe
                                ? Colors.green[700]
                                : Colors.grey[400],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.insert_drive_file,
                                color: message.isMe
                                    ? Colors.white
                                    : Colors.black87,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  message.fileName!,
                                  style: TextStyle(
                                    color: message.isMe
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (message.text.isNotEmpty &&
                          message.fileType != 'image' &&
                          message.fileType != 'document')
                        Text(
                          message.text,
                          style: TextStyle(
                            color: message.isMe ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.timestamp),
                            style: TextStyle(
                              color: message.isMe
                                  ? Colors.white70
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          if (message.isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.isRead == true
                                  ? Icons.done_all
                                  : Icons.done,
                              color: message.isRead == true
                                  ? Colors.blue[200]
                                  : Colors.white70,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (message.isMe && isSelected) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _deleteMessage(message.id),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ] else if (!message.isMe && isSelected) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _deleteMessage(message.id),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _fetchMessagesFromApi(silent: true);
      // Clear badge when returning to chat
      BadgeService().clearBadge();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _readStatusPollTimer?.cancel();
            _foregroundMessageSubscription?.cancel();
            CurrentChatState().clearCurrentChat();
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: widget.contact.avatarColor,
                  radius: 18,
                  child: Text(
                    widget.contact.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.contact.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contact.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.contact.isOnline ? "Online" : "Last seen recently",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchMessagesFromApi(silent: false),
            tooltip: 'Refresh messages',
          ),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          if (_isLoadingMessages)
            const LinearProgressIndicator(
              backgroundColor: Colors.grey,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    reverse: true, // ADD THIS - shows newest at bottom
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      // Reverse the index since list is reversed
                      final reversedIndex = _messages.length - 1 - index;
                      final message = _messages[reversedIndex];

                      return Column(
                        children: [
                          if (_shouldShowDateSeparator(reversedIndex))
                            _buildDateSeparator(message.timestamp),
                          _buildMessage(message),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.grey),
                  onPressed: _onCameraPressed,
                  tooltip: 'Camera',
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    decoration: InputDecoration(
                      hintText: "Type a message",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.attach_file, color: Colors.grey),
                        onPressed: _onAttachFilePressed,
                        tooltip: 'Attach file',
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _sendMessage(),
                    onTap: () {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) _scrollToBottom();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  backgroundColor: Colors.green,
                  mini: true,
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
