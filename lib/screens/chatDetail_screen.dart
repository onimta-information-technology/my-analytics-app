import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/models/chat_message.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

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
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  List<ChatMessage> _messages = [];
  String? _currentUserName;
  String? _currentUsersaved;
  String? _selectedMessageId;
  bool _isLoadingMessages = false;
  bool _isLoadingMore = false;

  // Pagination variables
  static const int _messagesPerPage = 30;
  int _currentPage = 0;
  bool _hasMoreMessages = true;

  // Optimization variables
  DateTime? _lastFetchTime;
  String? _lastMessageId;
  bool _hasLoadedInitialMessages = false;

  Timer? _messagePollingTimer;
  // static const Duration _pollingInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getCurrentUserName();
    _getCurrentUserNameonlyusemsgsend();

    // Load recent messages first for quick display
    _initializeMessages();

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // _startMessagePolling();
  }

  @override
  void dispose() {
    _messagePollingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when scrolled to top (for older messages)
    if (_scrollController.position.pixels <= 100 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  // Load initial recent messages only
  Future<void> _initializeMessages() async {
    await _loadRecentMessagesFromLocal();
    await _fetchNewMessagesFromApi(silent: false);
  }

  // Load only recent messages from local storage
  Future<void> _loadRecentMessagesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = 'messages_${widget.contact.chatUuid}';
      final jsonString = prefs.getString(storageKey);

      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        final allMessages = jsonList
            .map((json) => ChatMessage.fromJson(json))
            .toList();

        // Take only the last 30 messages for initial load
        final recentMessages = allMessages.length > _messagesPerPage
            ? allMessages.sublist(allMessages.length - _messagesPerPage)
            : allMessages;

        setState(() {
          _messages = recentMessages;
          _currentPage = 1;
          _hasMoreMessages = allMessages.length > _messagesPerPage;

          if (_messages.isNotEmpty) {
            _lastMessageId = _messages.last.apiMessageId ?? _messages.last.id;
            _lastFetchTime = _messages.last.timestamp;
          }
        });

        print('Loaded ${_messages.length} recent messages from local storage');
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading local messages: $e');
    }
  }

  // Load older messages when scrolling up
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = 'messages_${widget.contact.chatUuid}';
      final jsonString = prefs.getString(storageKey);

      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        final allMessages = jsonList
            .map((json) => ChatMessage.fromJson(json))
            .toList();

        final currentLoadedCount = (_currentPage) * _messagesPerPage;
        final remainingMessages = allMessages.length - currentLoadedCount;

        if (remainingMessages > 0) {
          final startIndex =
              allMessages.length - currentLoadedCount - _messagesPerPage;
          final endIndex = allMessages.length - currentLoadedCount;

          final olderMessages = allMessages.sublist(
            startIndex > 0 ? startIndex : 0,
            endIndex,
          );

          // Store current scroll position
          final currentScrollPosition = _scrollController.position.pixels;

          setState(() {
            _messages.insertAll(0, olderMessages);
            _currentPage++;
            _hasMoreMessages = startIndex > 0;
            _isLoadingMore = false;
          });

          // Restore scroll position
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(currentScrollPosition + 100);
            }
          });

          print(
            'Loaded ${olderMessages.length} more messages. Total: ${_messages.length}',
          );
        } else {
          setState(() {
            _hasMoreMessages = false;
            _isLoadingMore = false;
          });
        }
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more messages: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _getCurrentUserName() async {
    try {
      final userName = await StorageUtil.getUserName();
      setState(() {
        _currentUserName = userName;
      });
    } catch (e) {
      print('Error getting current user name: $e');
    }
  }

  Future<void> _getCurrentUserNameonlyusemsgsend() async {
    try {
      String? userName = await StorageUtil.getUserName();

      if (userName != null) {
        userName = userName
            .replaceAll(
              RegExp(
                r'^(Mr\.?|Ms\.?|Mrs\.?|Dr\.?|Prof\.?|M\.?)\s*',
                caseSensitive: false,
              ),
              '',
            )
            .trim();

        setState(() {
          _currentUsersaved = userName;
        });
      }
      print('Current user namesaved: $_currentUsersaved');
    } catch (e) {
      print('Error getting current user name: $e');
    }
  }

  // Save all messages to local storage
  Future<void> _saveMessagesToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = 'messages_${widget.contact.chatUuid}';

      // Load existing messages first
      final jsonString = prefs.getString(storageKey);
      List<ChatMessage> allMessages = [];

      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        allMessages = jsonList
            .map((json) => ChatMessage.fromJson(json))
            .toList();
      }

      // Merge with current messages (avoiding duplicates)
      final messageIds = allMessages.map((m) => m.apiMessageId ?? m.id).toSet();
      for (var msg in _messages) {
        if (!messageIds.contains(msg.apiMessageId ?? msg.id)) {
          allMessages.add(msg);
        }
      }

      // Sort by timestamp
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final jsonList = allMessages.map((message) => message.toJson()).toList();
      await prefs.setString(storageKey, jsonEncode(jsonList));
      print('Saved ${allMessages.length} messages to local storage');
    } catch (e) {
      print('Error saving messages to local: $e');
    }
  }

  // Fetch only new messages from API
  Future<void> _fetchNewMessagesFromApi({bool silent = false}) async {
    if (_isLoadingMessages && !silent) return;

    if (!silent) {
      setState(() {
        _isLoadingMessages = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('Token') ?? '';
      final chatId = widget.contact.chatUuid;

      final response = await http
          .get(
            Uri.parse(
              'https://ballysnotifications.onimtaitsl.com/api/chats/$chatId/messages',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true &&
            responseData['messages'] != null) {
          final List<dynamic> messagesJson = responseData['messages'];

          final List<ChatMessage> fetchedMessages = messagesJson
              .map(
                (json) =>
                    ChatMessage.fromApiResponse(json, _currentUserName ?? ''),
              )
              .toList();

          // Filter to get only new messages
          List<ChatMessage> newMessages = [];
          if (_hasLoadedInitialMessages && _lastFetchTime != null) {
            newMessages = fetchedMessages.where((msg) {
              return msg.timestamp.isAfter(_lastFetchTime!);
            }).toList();
          } else {
            // First load: take only recent messages
            newMessages = fetchedMessages.length > _messagesPerPage
                ? fetchedMessages.sublist(
                    fetchedMessages.length - _messagesPerPage,
                  )
                : fetchedMessages;
            _hasLoadedInitialMessages = true;
          }

          if (newMessages.isNotEmpty || !_hasLoadedInitialMessages) {
            setState(() {
              if (_hasLoadedInitialMessages) {
                // Remove duplicates based on message ID
                final existingIds = _messages
                    .map((m) => m.apiMessageId ?? m.id)
                    .toSet();
                final uniqueNewMessages = newMessages
                    .where(
                      (msg) =>
                          !existingIds.contains(msg.apiMessageId ?? msg.id),
                    )
                    .toList();

                _messages.addAll(uniqueNewMessages);
                print('Added ${uniqueNewMessages.length} new messages');
              } else {
                // First load: set recent messages only
                _messages = newMessages;
                print('Loaded ${_messages.length} recent messages from API');
              }

              // Update tracking variables
              if (_messages.isNotEmpty) {
                _lastMessageId =
                    _messages.last.apiMessageId ?? _messages.last.id;
                _lastFetchTime = _messages.last.timestamp;
              }

              if (!silent) {
                _isLoadingMessages = false;
              }
            });

            await _saveMessagesToLocal();
            await _markMessagesAsRead();

            if (widget.onMessageSent != null && _messages.isNotEmpty) {
              final lastMsg = _messages.last;
              widget.onMessageSent!(lastMsg.text);
            }

            _scrollToBottom();
          } else {
            print('No new messages found');
            if (!silent) {
              setState(() {
                _isLoadingMessages = false;
              });
            }
          }
        } else {
          if (!silent) {
            setState(() {
              _isLoadingMessages = false;
            });
          }
        }
      } else {
        print('Failed to fetch messages: ${response.statusCode}');
        if (!silent) {
          setState(() {
            _isLoadingMessages = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching messages from API: $e');
      if (!silent) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  // Rest of the methods remain the same...
  Future<void> _markMessagesAsRead() async {
    try {
      if (_currentUserName == null || _messages.isEmpty) return;

      final unreadMessageIds = _messages
          .where((msg) => !msg.isMe && msg.apiMessageId != null)
          .map((msg) => msg.apiMessageId!)
          .toList();

      if (unreadMessageIds.isEmpty) return;

      print('Marking ${unreadMessageIds.length} messages as read');

      final response = await FirebaseApiService.markMessagesAsRead(
        widget.contact.chatUuid,
        unreadMessageIds,
        _currentUserName!,
      );

      if (response['success'] == true) {
        print('Successfully marked messages as read');
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _deleteMessageFromApi(String chatId, String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('Token') ?? '';

      final response = await http.delete(
        Uri.parse(
          'https://ballysnotifications.onimtaitsl.com/api/chats/$chatId/messages/$messageId/soft-delete',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete message from server.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error deleting message via API: $e');
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
      print('Current user name is null');
      return null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('Token') ?? '';

      final response = await http.post(
        Uri.parse(
          'https://ballysnotifications.onimtaitsl.com/api/chat/send-message-with-notification',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "senderFirstName": _currentUsersaved,
          "recipientFirstName": widget.contact.firstName,
          "message": messageText,
          "title": "New Message from $_currentUserName",
          "body": messageText,
          "chatId": widget.contact.chatUuid,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
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
              );
            }
          });

          await _saveMessagesToLocal();
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
      print('Error sending message via API: $e');
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
      );

      setState(() {
        _messages.add(message);
        _lastMessageId = localMessageId;
        _lastFetchTime = now;
      });

      _messageController.clear();
      await _saveMessagesToLocal();
      _scrollToBottom();

      if (widget.onMessageSent != null) {
        widget.onMessageSent!(messageText);
      }

      await _sendMessageWithApi(messageText, localMessageId);
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

        await _saveMessagesToLocal();
        _scrollToBottom();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo captured successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error taking photo: $e');
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

        await _saveMessagesToLocal();
        _scrollToBottom();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image selected successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error picking image: $e');
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

        await _saveMessagesToLocal();
        _scrollToBottom();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document "${file.name}" selected!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error picking document: $e');
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
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} ${timestamp.hour >= 12 ? 'PM' : 'AM'}';
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

                await _saveMessagesToLocal();

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
              if (message.isMe) ...[
                const SizedBox(width: 8),
                if (isSelected)
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
              ] else if (isSelected) ...[
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
      print('App resumed - fetching new messages');
      _fetchNewMessagesFromApi(silent: true);
      // _startMessagePolling();
    } else if (state == AppLifecycleState.paused) {
      print('App paused - stopping message polling');
      _messagePollingTimer?.cancel();
    }
  }

  // void _startMessagePolling() {
  //   _messagePollingTimer?.cancel();

  //   _messagePollingTimer = Timer.periodic(_pollingInterval, (timer) {
  //     if (mounted) {
  //       _fetchNewMessagesFromApi(silent: true);
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _messagePollingTimer?.cancel();
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
            onPressed: () => _fetchNewMessagesFromApi(silent: false),
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
          if (_isLoadingMore)
            Container(
              padding: const EdgeInsets.all(8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Loading older messages...',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
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
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessage(_messages[index]);
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
