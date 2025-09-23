import 'package:ballys_reservation_app/providers/chat_api.dart';
import 'package:ballys_reservation_app/screens/chatDetail_screen.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Chat data model updated for new API structure
class ChatContact {
  final String id;
  final String chatUuid;
  final String name;
  final String firstName;
  final String lastMessage;
  final String time;
  final bool isOnline;
  final Color avatarColor;
  final String initials;
  final int unreadCount;
  final DateTime? lastMessageTime;
  final String? lastMessageSender;
  final List<String> participants;
  final DateTime createdAt;

  ChatContact({
    required this.id,
    required this.chatUuid,
    required this.name,
    this.firstName = '',
    required this.lastMessage,
    required this.time,
    this.isOnline = false,
    required this.avatarColor,
    required this.initials,
    this.unreadCount = 0,
    this.lastMessageTime,
    this.lastMessageSender,
    required this.participants,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'chatUuid': chatUuid,
    'name': name,
    'firstName': firstName,
    'lastMessage': lastMessage,
    'time': time,
    'isOnline': isOnline,
    'avatarColor': avatarColor.value,
    'initials': initials,
    'unreadCount': unreadCount,
    'lastMessageTime': lastMessageTime?.millisecondsSinceEpoch,
    'lastMessageSender': lastMessageSender,
    'participants': participants,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  static ChatContact fromJson(Map<String, dynamic> json) => ChatContact(
    id: json['id'],
    chatUuid: json['chatUuid'],
    name: json['name'],
    firstName: json['firstName'] ?? '',
    lastMessage: json['lastMessage'],
    time: json['time'],
    isOnline: json['isOnline'] ?? false,
    avatarColor: Color(json['avatarColor']),
    initials: json['initials'],
    unreadCount: json['unreadCount'] ?? 0,
    lastMessageTime: json['lastMessageTime'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['lastMessageTime'])
        : null,
    lastMessageSender: json['lastMessageSender'],
    participants: List<String>.from(json['participants'] ?? []),
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
  );

  // Factory constructor to create ChatContact from chat API response
  static ChatContact fromChatApiJson(
    Map<String, dynamic> json,
    String currentUserName, {
    Map<String, dynamic>? participantDetails,
  }) {
    final List<String> participants = List<String>.from(
      json['participants'] ?? [],
    );

    // Get the other participant's name (not the current user)
    final String otherParticipant = participants.firstWhere(
      (participant) => participant != currentUserName,
      orElse: () => participants.isNotEmpty ? participants[0] : 'Unknown',
    );

    final String name = otherParticipant;

    // Extract firstName from participantDetails if available
    String firstName = '';
    if (participantDetails != null &&
        participantDetails.containsKey(otherParticipant)) {
      firstName = participantDetails[otherParticipant]['firstName'] ?? '';
    }

    // If firstName is still empty, try to extract it from the name
    if (firstName.isEmpty) {
      // For names like "Mr Prathap", extract "Prathap"
      final nameParts = name.trim().split(' ');
      if (nameParts.length > 1) {
        firstName = nameParts.last; // Take the last part as firstName
      } else {
        firstName = name; // Use the full name if no spaces
      }
    }

    final String initials = _generateInitials(name);
    final Color avatarColor = _generateColorFromName(name);

    // Parse lastMessageTime to generate relative time
    final DateTime? lastMessageTime = json['lastMessageTime'] != null
        ? DateTime.parse(json['lastMessageTime'])
        : null;
    final String timeAgo = _getTimeAgo(lastMessageTime);

    final String lastMessage = json['lastMessage'] ?? 'No messages yet';

    return ChatContact(
      id: json['id'] ?? '',
      chatUuid: json['chatUuid'] ?? json['id'] ?? '',
      name: name,
      firstName: firstName, // Now properly set
      lastMessage: lastMessage,
      time: timeAgo,
      isOnline: participantDetails?[otherParticipant]?['isOnline'] ?? false,
      avatarColor: avatarColor,
      initials: initials,
      unreadCount: json['unreadCount'] ?? 0,
      lastMessageTime: lastMessageTime,
      lastMessageSender: json['lastMessageSender'],
      participants: participants,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  static String _generateInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';

    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'U';
    } else {
      final first = parts[0].isNotEmpty ? parts[0][0] : '';
      final last = parts[parts.length - 1].isNotEmpty
          ? parts[parts.length - 1][0]
          : '';
      return (first + last).toUpperCase();
    }
  }

  static Color _generateColorFromName(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
    ];

    final int hash = name.hashCode;
    return colors[hash.abs() % colors.length];
  }

  static String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isMe': isMe,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    text: json['text'],
    isMe: json['isMe'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
  );
}

List<ChatContact> _filteredUsers = [];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ChatContact> _contacts = [];
  List<ChatContact> _filteredContacts = [];
  List<ChatContact> _allUsers = []; // For new chat modal
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserName;
  String? _selectedContactId; // For tracking long-pressed contact

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _getCurrentUserName();
    await _fetchChatsFromApi();
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

  // New method to create chat
  Future<String?> _createChat(String receiverName) async {
    if (_currentUserName == null) {
      print('Current user name is null');
      return null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('Token') ?? '';

      final response = await http.post(
        Uri.parse(
          'https://ballysnotifications.onimtaitsl.com/api/chats/create',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "participants": [receiverName, _currentUserName],
        }),
      );

      print('Create chat response status: ${response.statusCode}');
      print('Create chat response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['chatId'] != null) {
          return responseData['chatId'];
        }
      }

      print('Failed to create chat: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error creating chat: $e');
      return null;
    }
  }

  // New method to delete chat
  Future<bool> _deleteChat(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('Token') ?? '';

      final response = await http.delete(
        Uri.parse(
          'https://ballysnotifications.onimtaitsl.com/api/chats/$chatId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Delete chat response status: ${response.statusCode}');
      print('Delete chat response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting chat: $e');
      return false;
    }
  }

  void _showDeleteConfirmation(ChatContact contact) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Chat'),
          content: Text(
            'Are you sure you want to delete the chat with ${contact.name}?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _selectedContactId = null; // Clear selection
                });
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();

                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 16),
                        Text('Deleting chat...'),
                      ],
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );

                // Delete chat
                final success = await _deleteChat(contact.chatUuid);

                // Hide loading
                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                if (success) {
                  // Remove from local list
                  setState(() {
                    _contacts.removeWhere(
                      (c) => c.chatUuid == contact.chatUuid,
                    );
                    _filteredContacts.removeWhere(
                      (c) => c.chatUuid == contact.chatUuid,
                    );
                    _selectedContactId = null;
                  });

                  // Update cache
                  await _saveChats();

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete chat'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }

                setState(() {
                  _selectedContactId = null; // Clear selection
                });
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchChatsFromApi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch both chats and users data
      final chatData = await ChatApi.fetchUserChats();
      final userData = await ChatApi.fetchAllUsers();

      if (chatData['chats'] != null) {
        final List<dynamic> chats = chatData['chats'];

        // Create a map of user details for quick lookup
        Map<String, dynamic> userDetailsMap = {};
        if (userData['users'] != null) {
          final List<dynamic> users = userData['users'];
          for (var user in users) {
            final userName = user['name'] ?? user['id'] ?? '';
            userDetailsMap[userName] = user;
          }
        }

        setState(() {
          _contacts = chats
              .map(
                (chat) => ChatContact.fromChatApiJson(
                  chat,
                  _currentUserName ?? '',
                  participantDetails: userDetailsMap,
                ),
              )
              .toList();
          _filteredContacts = List.from(_contacts);
          _isLoading = false;
        });

        // Save chats to local storage
        await _saveChats();
      } else {
        setState(() {
          _errorMessage = 'No chats data received';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });

      // Fallback to cached data if available
      await _loadChats();
    }
  }

  Future<void> _fetchAllUsersForNewChat() async {
    try {
      final data = await ChatApi.fetchAllUsers();

      if (data['users'] != null) {
        final List<dynamic> users = data['users'];
        // Convert users to ChatContact format for display in modal
        final List<ChatContact> userContacts = users.map((user) {
          final String name = user['name'] ?? user['firstName'] ?? 'Unknown';
          final String firstName = user['firstName'] ?? name;
          final String initials = ChatContact._generateInitials(name);
          final Color avatarColor = ChatContact._generateColorFromName(name);

          return ChatContact(
            id: user['id'] ?? user['userUuid'] ?? '',
            chatUuid: '', // Empty for new chats
            name: name,
            firstName: firstName, // Properly set from API response
            lastMessage: user['isOnline'] == true ? 'Online' : 'Offline',
            time: '',
            isOnline: user['isOnline'] ?? false,
            avatarColor: avatarColor,
            initials: initials,
            unreadCount: 0,
            participants: [name],
            createdAt: DateTime.now(),
          );
        }).toList();

        setState(() {
          _allUsers = userContacts;
          _filteredUsers = List.from(userContacts);
        });
      }
    } catch (e) {
      print('Error fetching all users: $e');
    }
  }

  Future<void> _saveChats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _contacts.map((contact) => contact.toJson()).toList();
    await prefs.setString('chat_contacts', jsonEncode(jsonList));
  }

  Future<void> _loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('chat_contacts');
    if (jsonString != null) {
      try {
        final jsonList = jsonDecode(jsonString) as List;
        setState(() {
          _contacts = jsonList
              .map((json) => ChatContact.fromJson(json))
              .toList();
          _filteredContacts = List.from(_contacts);
        });
      } catch (e) {
        print('Error loading cached chats: $e');
      }
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredContacts = List.from(_contacts);
      } else {
        _filteredContacts = _contacts
            .where(
              (contact) =>
                  contact.name.toLowerCase().contains(query.toLowerCase()) ||
                  contact.lastMessage.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  contact.participants.any(
                    (participant) =>
                        participant.toLowerCase().contains(query.toLowerCase()),
                  ),
            )
            .toList();
      }
    });
  }

  List<ChatContact> _getFilteredContactsForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: // All
        return _filteredContacts;
      case 1: // Unread
        return _filteredContacts.where((c) => c.unreadCount > 0).toList();
      case 2: // Groups
        return _filteredContacts
            .where((c) => c.participants.length > 2)
            .toList();
      case 3: // Favorites
        return []; // No favorites in this example
      default:
        return _filteredContacts;
    }
  }

  Widget _buildContactCard(ChatContact contact) {
    final bool hasLastMessage =
        contact.lastMessage.isNotEmpty &&
        contact.lastMessage != 'No messages yet';
    final bool isSelected = _selectedContactId == contact.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: isSelected ? 4 : 0,
      color: isSelected ? Colors.red.withOpacity(0.1) : Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (isSelected) {
            // If selected, clear selection
            setState(() {
              _selectedContactId = null;
            });
            return;
          }

          // Create chat before navigating to IndividualChatScreen
          final chatId = await _createChat(
            contact.firstName.isNotEmpty ? contact.firstName : contact.name,
          );

          // Create a new contact with the chatId for the IndividualChatScreen
          final contactWithChatId = ChatContact(
            id: contact.id,
            chatUuid: chatId ?? contact.chatUuid,
            name: contact.name,
            firstName: contact.firstName.isNotEmpty
                ? contact.firstName
                : contact.name,
            lastMessage: contact.lastMessage,
            time: contact.time,
            isOnline: contact.isOnline,
            avatarColor: contact.avatarColor,
            initials: contact.initials,
            unreadCount: contact.unreadCount,
            lastMessageTime: contact.lastMessageTime,
            lastMessageSender: contact.lastMessageSender,
            participants: contact.participants,
            createdAt: contact.createdAt,
          );

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  IndividualChatScreen(contact: contactWithChatId),
            ),
          );
        },
        onLongPress: () {
          setState(() {
            _selectedContactId = contact.id;
          });

          // Provide haptic feedback
          // HapticFeedback.lightImpact(); // Uncomment if you want haptic feedback
        },
        child: ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: contact.avatarColor,
                radius: 25,
                child: Text(
                  contact.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (contact.isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            contact.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasLastMessage) ...[
                Text(
                  contact.lastMessage,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: contact.unreadCount > 0
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (contact.lastMessageSender != null)
                  Text(
                    'by ${contact.lastMessageSender}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
              ] else
                Text(
                  'No messages yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
            ],
          ),
          trailing: isSelected
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteConfirmation(contact),
                      tooltip: 'Delete chat',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _selectedContactId = null;
                        });
                      },
                      tooltip: 'Cancel',
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      contact.time,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    if (contact.unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${contact.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (hasLastMessage && contact.unreadCount == 0)
                      const Icon(Icons.done_all, color: Colors.grey, size: 16),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildChatList(int tabIndex) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text('Loading chats...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchChatsFromApi,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final contacts = _getFilteredContactsForTab(tabIndex);

    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 50, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              tabIndex == 0
                  ? "No chats found"
                  : "No ${['all', 'unread', 'groups', 'favorites'][tabIndex]} chats",
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _fetchChatsFromApi,
              child: const Text(
                "Refresh chats",
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchChatsFromApi,
      child: GestureDetector(
        onTap: () {
          // Clear selection when tapping outside
          if (_selectedContactId != null) {
            setState(() {
              _selectedContactId = null;
            });
          }
        },
        child: ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            return _buildContactCard(contacts[index]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_selectedContactId != null ? "Select action" : "Chats"),
            Text(
              _selectedContactId != null
                  ? "1 selected"
                  : "${_contacts.length} conversations",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),

        backgroundColor: _selectedContactId != null ? Colors.red : Colors.green,
        foregroundColor: Colors.white,
        leading: _selectedContactId != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedContactId = null;
                  });
                },
              )
            : null,
        actions: _selectedContactId != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    final contact = _contacts.firstWhere(
                      (c) => c.id == _selectedContactId,
                    );
                    _showDeleteConfirmation(contact);
                  },
                ),
              ]
            : [
                // IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    context.push('/menu');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchChatsFromApi,
                ),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
        bottom: _selectedContactId == null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(100),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          onChanged: _filterContacts,
                          decoration: InputDecoration(
                            hintText: "Search chats...",
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey.shade200,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      // Tabs
                      TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.green,
                        labelColor: Colors.green,
                        unselectedLabelColor: Colors.black54,
                        tabs: const [
                          Tab(text: "All"),
                          Tab(text: "Unread"),
                          Tab(text: "Groups"),
                          Tab(text: "Favorites"),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildChatList(0),
              _buildChatList(1),
              _buildChatList(2),
              _buildChatList(3),
            ],
          ),
          const Watermark(),
          if (_errorMessage != null && _contacts.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.orange.withOpacity(0.9),
                child: Text(
                  'Warning: ${_errorMessage!}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedContactId == null
          ? // Replace the FloatingActionButton's onPressed method with this:
            FloatingActionButton(
              backgroundColor: Colors.green,
              onPressed: () async {
                // Fetch all users when opening the modal
                await _fetchAllUsersForNewChat();

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (BuildContext context, StateSetter setModalState) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          height: MediaQuery.of(context).size.height * 0.8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                decoration: InputDecoration(
                                  hintText: "Search contacts...",
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                onChanged: (query) {
                                  setModalState(() {
                                    if (query.isEmpty) {
                                      _filteredUsers = List.from(_allUsers);
                                    } else {
                                      _filteredUsers = _allUsers
                                          .where(
                                            (user) =>
                                                user.name
                                                    .toLowerCase()
                                                    .contains(
                                                      query.toLowerCase(),
                                                    ) ||
                                                user.firstName
                                                    .toLowerCase()
                                                    .contains(
                                                      query.toLowerCase(),
                                                    ),
                                          )
                                          .toList();
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Start New Chat",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: _allUsers.isEmpty
                                    ? const Center(
                                        child: Text('No contacts available'),
                                      )
                                    : ListView.builder(
                                        itemCount: _filteredUsers.length,
                                        itemBuilder: (context, index) {
                                          final contact = _filteredUsers[index];
                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor:
                                                  contact.avatarColor,
                                              child: Text(
                                                contact.initials,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            title: Text(contact.name),
                                            subtitle: Text(
                                              contact.isOnline
                                                  ? "Online"
                                                  : "Offline",
                                            ),
                                            onTap: () async {
                                              // Store the navigator for safe navigation
                                              final navigator = Navigator.of(
                                                context,
                                              );
                                              final scaffoldMessenger =
                                                  ScaffoldMessenger.of(context);

                                              // Close the bottom sheet first
                                              navigator.pop();

                                              // Show inline loading message instead of modal
                                              scaffoldMessenger.showSnackBar(
                                                const SnackBar(
                                                  content: Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(Colors.white),
                                                        ),
                                                      ),
                                                      SizedBox(width: 16),
                                                      Text('Creating chat...'),
                                                    ],
                                                  ),
                                                  duration: Duration(
                                                    seconds: 30,
                                                  ),
                                                  backgroundColor: Colors.blue,
                                                ),
                                              );

                                              try {
                                                // Create chat
                                                final chatId =
                                                    await _createChat(
                                                      contact
                                                              .firstName
                                                              .isNotEmpty
                                                          ? contact.firstName
                                                          : contact.name,
                                                    );

                                                // Remove loading message
                                                scaffoldMessenger
                                                    .hideCurrentSnackBar();

                                                // Create contact with chatId
                                                final contactWithChatId =
                                                    ChatContact(
                                                      id: contact.id,
                                                      chatUuid:
                                                          chatId ??
                                                          contact.chatUuid ??
                                                          '',
                                                      name: contact.name,
                                                      firstName:
                                                          contact
                                                              .firstName
                                                              .isNotEmpty
                                                          ? contact.firstName
                                                          : contact.name,
                                                      lastMessage:
                                                          contact.lastMessage,
                                                      time: contact.time,
                                                      isOnline:
                                                          contact.isOnline,
                                                      avatarColor:
                                                          contact.avatarColor,
                                                      initials:
                                                          contact.initials,
                                                      unreadCount:
                                                          contact.unreadCount,
                                                      lastMessageTime: contact
                                                          .lastMessageTime,
                                                      lastMessageSender: contact
                                                          .lastMessageSender,
                                                      participants:
                                                          contact.participants,
                                                      createdAt:
                                                          contact.createdAt,
                                                    );

                                                // Navigate to IndividualChatScreen
                                                await navigator.push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        IndividualChatScreen(
                                                          contact:
                                                              contactWithChatId,
                                                        ),
                                                  ),
                                                );

                                                // Refresh chats after returning from IndividualChatScreen
                                                _fetchChatsFromApi();
                                              } catch (e) {
                                                // Remove loading message and show error
                                                scaffoldMessenger
                                                    .hideCurrentSnackBar();

                                                print(
                                                  'Error in contact tap: $e',
                                                );

                                                // Show error message
                                                scaffoldMessenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Error creating chat: $e',
                                                    ),
                                                    backgroundColor:
                                                        Colors.orange,
                                                  ),
                                                );

                                                // Navigate anyway with existing contact data
                                                final contactWithChatId =
                                                    ChatContact(
                                                      id: contact.id,
                                                      chatUuid:
                                                          contact.chatUuid,
                                                      name: contact.name,
                                                      firstName:
                                                          contact
                                                              .firstName
                                                              .isNotEmpty
                                                          ? contact.firstName
                                                          : contact.name,
                                                      lastMessage:
                                                          contact.lastMessage,
                                                      time: contact.time,
                                                      isOnline:
                                                          contact.isOnline,
                                                      avatarColor:
                                                          contact.avatarColor,
                                                      initials:
                                                          contact.initials,
                                                      unreadCount:
                                                          contact.unreadCount,
                                                      lastMessageTime: contact
                                                          .lastMessageTime,
                                                      lastMessageSender: contact
                                                          .lastMessageSender,
                                                      participants:
                                                          contact.participants,
                                                      createdAt:
                                                          contact.createdAt,
                                                    );

                                                await navigator.push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        IndividualChatScreen(
                                                          contact:
                                                              contactWithChatId,
                                                        ),
                                                  ),
                                                );
                                              }
                                            },
                                          );
                                        },
                                      ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Close"),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
              child: const Icon(Icons.chat, color: Colors.white),
            )
          : null, // Hide FAB when contact is selected
    );
  }
}
