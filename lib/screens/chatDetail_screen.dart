import 'package:ballys_reservation_app/screens/chat_screen.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

// Updated ChatMessage class with API fields and file support
class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String? apiMessageId;
  final String? apiChatId;
  final String? filePath;
  final String? fileType; // 'image', 'document', etc.
  final String? fileName;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.apiMessageId,
    this.apiChatId,
    this.filePath,
    this.fileType,
    this.fileName,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isMe,
    DateTime? timestamp,
    String? apiMessageId,
    String? apiChatId,
    String? filePath,
    String? fileType,
    String? fileName,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isMe: isMe ?? this.isMe,
      timestamp: timestamp ?? this.timestamp,
      apiMessageId: apiMessageId ?? this.apiMessageId,
      apiChatId: apiChatId ?? this.apiChatId,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileName: fileName ?? this.fileName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isMe': isMe,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'apiMessageId': apiMessageId,
    'apiChatId': apiChatId,
    'filePath': filePath,
    'fileType': fileType,
    'fileName': fileName,
  };

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    text: json['text'],
    isMe: json['isMe'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    apiMessageId: json['apiMessageId'],
    apiChatId: json['apiChatId'],
    filePath: json['filePath'],
    fileType: json['fileType'],
    fileName: json['fileName'],
  );
}

class IndividualChatScreen extends StatefulWidget {
  final ChatContact contact;

  const IndividualChatScreen({super.key, required this.contact});

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  String? _currentUserName;
  String? _selectedMessageId;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadInitialMessages();
    _getCurrentUserName();
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

  void _loadInitialMessages() {
    // Add some initial messages if none exist
    if (_messages.isEmpty) {
      _messages = [
        ChatMessage(
          id: '1',
          text: 'Hello! How can I help you today?',
          isMe: false,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];
      _saveMessages();
    }
  }

  // Method to delete message from API
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

      print('Delete message response status: ${response.statusCode}');
      print('Delete message response body: ${response.body}');

      if (response.statusCode != 200) {
        print('Failed to delete message via API: ${response.statusCode}');
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to delete message from server. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      print('Error deleting message via API: $e');
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error deleting message. Please check your connection.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
  }

  // Method to send message with API call
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
          "senderFirstName": "Anushka",
          "recipientFirstName": widget.contact.firstName,
          "message": messageText,
          "title": "New Message from $_currentUserName",
          "body": messageText,
          "chatId": widget.contact.chatUuid,
        }),
      );

      print('Send message response status: ${response.statusCode}');
      print('Send message response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final messageId = responseData['data']['messageId'];
          final chatId = responseData['data']['chatId'];

          // Update the local message with API IDs
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
          _saveMessages();

          return messageId;
        }
      } else {
        print('Failed to send message via API: ${response.statusCode}');
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error sending message via API: $e');
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error sending message. Please check your connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return null;
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('messages_${widget.contact.id}');
    if (jsonString != null) {
      final jsonList = jsonDecode(jsonString) as List;
      setState(() {
        _messages = jsonList.map((json) => ChatMessage.fromJson(json)).toList();
      });
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _messages.map((message) => message.toJson()).toList();
    await prefs.setString(
      'messages_${widget.contact.id}',
      jsonEncode(jsonList),
    );
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      final messageText = _messageController.text.trim();
      final localMessageId = DateTime.now().millisecondsSinceEpoch.toString();

      final message = ChatMessage(
        id: localMessageId,
        text: messageText,
        isMe: true,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(message);
      });

      _messageController.clear();
      _saveMessages();
      _scrollToBottom();

      // Send message via API and update with server IDs
      await _sendMessageWithApi(messageText, localMessageId);
    }
  }

  // Handler for camera icon
  void _onCameraPressed() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        // Create a message with the image
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

        _saveMessages();
        _scrollToBottom();

        // TODO: Upload image to server and send message
        // You can implement this based on your API requirements
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

  // Handler for file attachment icon
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

  // Pick image from gallery
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

        _saveMessages();
        _scrollToBottom();

        // TODO: Upload image to server
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

  // Pick document
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

        _saveMessages();
        _scrollToBottom();

        // TODO: Upload document to server
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

                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Deleting message...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                // Find the message to get API IDs
                final message = _messages.firstWhere(
                  (msg) => msg.id == messageId,
                );

                // Check if message has API IDs (chatId and messageId from server)
                if (message.apiChatId != null && message.apiMessageId != null) {
                  // Call API to delete message
                  await _deleteMessageFromApi(
                    message.apiChatId!,
                    message.apiMessageId!,
                  );
                }

                // Remove from local storage regardless of API call result
                setState(() {
                  _messages.removeWhere((message) => message.id == messageId);
                  _selectedMessageId = null;
                });
                _saveMessages();

                // Show confirmation
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
                      // Display image if fileType is image
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
                      // Display document info if fileType is document
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
                      // Display text message
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
                            const Icon(
                              Icons.done_all,
                              color: Colors.white70,
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
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
                // Camera icon button
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.grey),
                  onPressed: _onCameraPressed,
                  tooltip: 'Camera',
                ),
                const SizedBox(width: 4),
                // Text input field with attach icon inside
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
                // Send button
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
