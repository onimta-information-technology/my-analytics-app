import 'package:ballys_reservation_app/screens/chatDetail_screen.dart';
import 'package:flutter/material.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Chat data model
class ChatContact {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final bool isOnline;
  final Color avatarColor;
  final String initials;
  final int unreadCount;
  final String? email;
  final String? firstName;
  final DateTime? lastSeen;

  ChatContact({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.isOnline = false,
    required this.avatarColor,
    required this.initials,
    this.unreadCount = 0,
    this.email,
    this.firstName,
    this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lastMessage': lastMessage,
    'time': time,
    'isOnline': isOnline,
    'avatarColor': avatarColor.value,
    'initials': initials,
    'unreadCount': unreadCount,
    'email': email,
    'firstName': firstName,
    'lastSeen': lastSeen?.millisecondsSinceEpoch,
  };

  static ChatContact fromJson(Map<String, dynamic> json) => ChatContact(
    id: json['id'],
    name: json['name'],
    lastMessage: json['lastMessage'],
    time: json['time'],
    isOnline: json['isOnline'],
    avatarColor: Color(json['avatarColor']),
    initials: json['initials'],
    unreadCount: json['unreadCount'] ?? 0,
    email: json['email'],
    firstName: json['firstName'],
    lastSeen: json['lastSeen'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['lastSeen'])
        : null,
  );

  // Factory constructor to create ChatContact from API response
  static ChatContact fromApiJson(Map<String, dynamic> json) {
    final String name = json['name'] ?? json['firstName'] ?? 'Unknown';
    final String initials = _generateInitials(name);
    final Color avatarColor = _generateColorFromName(name);

    // Parse lastSeen to generate relative time
    final DateTime? lastSeen = json['lastSeen'] != null
        ? DateTime.parse(json['lastSeen'])
        : null;
    final String timeAgo = _getTimeAgo(lastSeen);

    return ChatContact(
      id: json['id'] ?? json['userUuid'] ?? '',
      name: name,
      lastMessage: json['isOnline'] == true ? 'Online' : 'Last seen $timeAgo',
      time: timeAgo,
      isOnline: json['isOnline'] ?? false,
      avatarColor: avatarColor,
      initials: initials,
      unreadCount:
          0, // Default to 0, can be updated based on actual unread messages
      email: json['email'],
      firstName: json['firstName'],
      lastSeen: lastSeen,
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
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchContactsFromApi();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchContactsFromApi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://ballysnotifications.onimtaitsl.com/api/users'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true && data['users'] != null) {
          final List<dynamic> users = data['users'];

          setState(() {
            _contacts = users
                .map((user) => ChatContact.fromApiJson(user))
                .toList();
            _filteredContacts = List.from(_contacts);
            _isLoading = false;
          });

          // Save contacts to local storage
          await _saveChats();
        } else {
          setState(() {
            _errorMessage = 'Invalid response format';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch contacts: ${response.statusCode}';
          _isLoading = false;
        });

        // Fallback to cached data if available
        await _loadChats();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });

      // Fallback to cached data if available
      await _loadChats();
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
      final jsonList = jsonDecode(jsonString) as List;
      setState(() {
        _contacts = jsonList.map((json) => ChatContact.fromJson(json)).toList();
        _filteredContacts = List.from(_contacts);
      });
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
                  (contact.firstName?.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ??
                      false) ||
                  (contact.email?.toLowerCase().contains(query.toLowerCase()) ??
                      false),
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
        return []; // No groups in this example
      case 3: // Favorites
        return []; // No favorites in this example
      default:
        return _filteredContacts;
    }
  }

  Widget _buildContactCard(ChatContact contact) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: Colors.transparent,
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
        subtitle: Text(
          contact.lastMessage,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
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
            if (contact.lastMessage.isNotEmpty && contact.unreadCount == 0)
              Icon(
                contact.isOnline ? Icons.done_all : Icons.access_time,
                color: contact.isOnline ? Colors.green : Colors.grey,
                size: 16,
              ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => IndividualChatScreen(contact: contact),
            ),
          );
        },
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
            Text('Loading contacts...'),
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
              onPressed: _fetchContactsFromApi,
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
              onPressed: _fetchContactsFromApi,
              child: const Text(
                "Refresh contacts",
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchContactsFromApi,
      child: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          return _buildContactCard(contacts[index]);
        },
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
            const Text("Chats"),
            Text(
              "${_contacts.length} conversations",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchContactsFromApi,
          ),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
        bottom: PreferredSize(
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
        ),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
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
                        // Implement local search in modal
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
                      child: _contacts.isEmpty
                          ? const Center(child: Text('No contacts available'))
                          : ListView.builder(
                              itemCount: _contacts.length,
                              itemBuilder: (context, index) {
                                final contact = _contacts[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: contact.avatarColor,
                                    child: Text(
                                      contact.initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  title: Text(contact.name),
                                  subtitle: Text(
                                    contact.isOnline ? "Online" : "Offline",
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            IndividualChatScreen(
                                              contact: contact,
                                            ),
                                      ),
                                    );
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
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }
}
