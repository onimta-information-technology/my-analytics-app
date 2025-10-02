import 'package:ballys_reservation_app/components/notification_banner.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/screens/chatDetail_screen.dart';
import 'package:flutter/material.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

List<ChatContact> _filteredUsers = [];

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic>? notificationData;
  const ChatScreen({super.key, this.notificationData});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ChatContact> _contacts = [];
  List<ChatContact> _filteredContacts = [];
  List<ChatContact> _allUsers = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserName;
  String? _selectedContactId;
  bool _hasProcessedNotification = false;

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
    await _getName();
    await _fetchChatsFromApi();
    _checkAndOpenNotificationChat();
  }

  void _checkAndOpenNotificationChat() {
    if (_hasProcessedNotification) return;

    if (widget.notificationData != null &&
        widget.notificationData!['openChat'] == true) {
      final chatId = widget.notificationData!['chatId'] as String?;
      final senderName = widget.notificationData!['senderName'] as String?;
      final senderId = widget.notificationData!['senderId'] as String?;

      print('Processing notification: chatId=$chatId, sender=$senderName');

      if (chatId != null && chatId.isNotEmpty) {
        _hasProcessedNotification = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openSpecificChat(chatId, senderName, senderId);
        });
      }
    }
  }

  void _openSpecificChat(String chatId, String? senderName, String? senderId) {
    ChatContact? targetContact = _contacts.cast<ChatContact?>().firstWhere(
      (contact) => contact?.chatUuid == chatId,
      orElse: () => null,
    );

    if (targetContact == null && senderName != null) {
      targetContact = _contacts.cast<ChatContact?>().firstWhere(
        (contact) =>
            contact?.name.toLowerCase().contains(senderName.toLowerCase()) ==
                true ||
            contact?.firstName.toLowerCase().contains(
                  senderName.toLowerCase(),
                ) ==
                true,
        orElse: () => null,
      );
    }

    if (targetContact != null) {
      print('Found contact: ${targetContact.name}, navigating to chat');

      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => IndividualChatScreen(
                contact: targetContact!,
                onMessageSent: (String lastMessage) {
                  _updateContactLastMessage(targetContact!.id, lastMessage);
                },
              ),
            ),
          )
          .then((_) {
            _fetchChatsFromApi();
          });
    } else {
      print('Contact not found for chatId: $chatId, sender: $senderName');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            senderName != null
                ? 'Chat with $senderName not found. Refreshing...'
                : 'Chat not found. Refreshing...',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );

      _fetchChatsFromApi().then((_) {
        if (_contacts.isNotEmpty) {
          final refreshedContact = _contacts.cast<ChatContact?>().firstWhere(
            (contact) =>
                contact?.chatUuid == chatId ||
                (senderName != null &&
                    contact?.name.toLowerCase().contains(
                          senderName.toLowerCase(),
                        ) ==
                        true),
            orElse: () => null,
          );

          if (refreshedContact != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    IndividualChatScreen(contact: refreshedContact!),
              ),
            );
          }
        }
      });
    }
  }

  Future<void> _getName() async {
    try {
      final userName = await FirebaseApiService.getName();
      setState(() {
        _currentUserName = userName;
      });
    } catch (e) {
      print('Error getting current user name: $e');
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
                  _selectedContactId = null;
                });
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();

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

                final success = await FirebaseApiService.deleteChat(
                  contact.chatUuid,
                );

                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                if (success) {
                  setState(() {
                    _contacts.removeWhere(
                      (c) => c.chatUuid == contact.chatUuid,
                    );
                    _filteredContacts.removeWhere(
                      (c) => c.chatUuid == contact.chatUuid,
                    );
                    _selectedContactId = null;
                  });

                  await _saveChats();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete chat'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }

                setState(() {
                  _selectedContactId = null;
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
      final chatData = await FirebaseApiService.fetchUserChats();
      final userData = await FirebaseApiService.fetchAllUsers();

      if (chatData['chats'] != null) {
        final List<dynamic> chats = chatData['chats'];

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

      await _loadChats();
    }
  }

  Future<void> _fetchAllUsersForNewChat() async {
    try {
      final data = await FirebaseApiService.fetchAllUsers();

      if (data['users'] != null) {
        final List<dynamic> users = data['users'];
        final List<ChatContact> userContacts = users.map((user) {
          final String name = user['name'] ?? user['firstName'] ?? 'Unknown';
          final String firstName = user['firstName'] ?? name;
          final String initials = ChatContact.generateInitials(name);
          final Color avatarColor = ChatContact.generateColorFromName(name);

          return ChatContact(
            id: user['id'] ?? user['userUuid'] ?? '',
            chatUuid: '',
            name: name,
            firstName: firstName,
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
      case 0:
        return _filteredContacts;
      case 1:
        return _filteredContacts.where((c) => c.unreadCount > 0).toList();
      case 2:
        return _filteredContacts
            .where((c) => c.participants.length > 2)
            .toList();
      case 3:
        return [];
      default:
        return _filteredContacts;
    }
  }

  void _updateContactLastMessage(String contactId, String lastMessage) {
    setState(() {
      final index = _contacts.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        _contacts[index] = ChatContact(
          id: _contacts[index].id,
          chatUuid: _contacts[index].chatUuid,
          name: _contacts[index].name,
          firstName: _contacts[index].firstName,
          lastMessage: lastMessage,
          time: 'now',
          isOnline: _contacts[index].isOnline,
          avatarColor: _contacts[index].avatarColor,
          initials: _contacts[index].initials,
          unreadCount: _contacts[index].unreadCount,
          lastMessageTime: DateTime.now(),
          lastMessageSender: _currentUserName,
          participants: _contacts[index].participants,
          createdAt: _contacts[index].createdAt,
        );

        final filteredIndex = _filteredContacts.indexWhere(
          (c) => c.id == contactId,
        );
        if (filteredIndex != -1) {
          _filteredContacts[filteredIndex] = _contacts[index];
        }
      }
    });
    _saveChats();
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
            setState(() {
              _selectedContactId = null;
            });
            return;
          }

          final chatId = await FirebaseApiService.createChat(contact.name);

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

          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => IndividualChatScreen(
                    contact: contactWithChatId,
                    onMessageSent: (String lastMessage) {
                      _updateContactLastMessage(contact.id, lastMessage);
                    },
                  ),
                ),
              )
              .then((_) {
                _fetchChatsFromApi();
              });
        },
        onLongPress: () {
          setState(() {
            _selectedContactId = contact.id;
          });
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
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
          backgroundColor: _selectedContactId != null
              ? Colors.red
              : Colors.green,
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
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {},
                  ),
                ],
          bottom: _selectedContactId == null
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(100),
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
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
        body: Column(
          children: [
            const NotificationBanner(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChatList(0),
                  _buildChatList(1),
                  _buildChatList(2),
                  _buildChatList(3),
                ],
              ),
            ),
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
            ? FloatingActionButton(
                backgroundColor: Colors.green,
                onPressed: () async {
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
                          return GestureDetector(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                            },
                            child: Container(
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                            child: Text(
                                              'No contacts available',
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: _filteredUsers.length,
                                            itemBuilder: (context, index) {
                                              final contact =
                                                  _filteredUsers[index];
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
                                                  final navigator =
                                                      Navigator.of(context);
                                                  final scaffoldMessenger =
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      );

                                                  navigator.pop();

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
                                                                  >(
                                                                    Colors
                                                                        .white,
                                                                  ),
                                                            ),
                                                          ),
                                                          SizedBox(width: 16),
                                                          Text(
                                                            'Creating chat...',
                                                          ),
                                                        ],
                                                      ),
                                                      duration: Duration(
                                                        seconds: 30,
                                                      ),
                                                      backgroundColor:
                                                          Colors.blue,
                                                    ),
                                                  );

                                                  try {
                                                    final chatId =
                                                        await FirebaseApiService.createChat(
                                                          contact.name,
                                                        );

                                                    scaffoldMessenger
                                                        .hideCurrentSnackBar();

                                                    final contactWithChatId =
                                                        ChatContact(
                                                          id: contact.id,
                                                          chatUuid:
                                                              chatId ??
                                                              contact.chatUuid,
                                                          name: contact.name,
                                                          firstName:
                                                              contact
                                                                  .firstName
                                                                  .isNotEmpty
                                                              ? contact
                                                                    .firstName
                                                              : contact.name,
                                                          lastMessage: contact
                                                              .lastMessage,
                                                          time: contact.time,
                                                          isOnline:
                                                              contact.isOnline,
                                                          avatarColor: contact
                                                              .avatarColor,
                                                          initials:
                                                              contact.initials,
                                                          unreadCount: contact
                                                              .unreadCount,
                                                          lastMessageTime: contact
                                                              .lastMessageTime,
                                                          lastMessageSender: contact
                                                              .lastMessageSender,
                                                          participants: contact
                                                              .participants,
                                                          createdAt:
                                                              contact.createdAt,
                                                        );

                                                    await navigator.push(
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            IndividualChatScreen(
                                                              contact:
                                                                  contactWithChatId,
                                                              onMessageSent:
                                                                  (
                                                                    String
                                                                    lastMessage,
                                                                  ) {
                                                                    _updateContactLastMessage(
                                                                      contact
                                                                          .id,
                                                                      lastMessage,
                                                                    );
                                                                  },
                                                            ),
                                                      ),
                                                    );

                                                    _fetchChatsFromApi();
                                                  } catch (e) {
                                                    scaffoldMessenger
                                                        .hideCurrentSnackBar();

                                                    print(
                                                      'Error in contact tap: $e',
                                                    );

                                                    scaffoldMessenger.showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Error creating chat: $e',
                                                        ),
                                                        backgroundColor:
                                                            Colors.orange,
                                                      ),
                                                    );

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
                                                              ? contact
                                                                    .firstName
                                                              : contact.name,
                                                          lastMessage: contact
                                                              .lastMessage,
                                                          time: contact.time,
                                                          isOnline:
                                                              contact.isOnline,
                                                          avatarColor: contact
                                                              .avatarColor,
                                                          initials:
                                                              contact.initials,
                                                          unreadCount: contact
                                                              .unreadCount,
                                                          lastMessageTime: contact
                                                              .lastMessageTime,
                                                          lastMessageSender: contact
                                                              .lastMessageSender,
                                                          participants: contact
                                                              .participants,
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
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                child: const Icon(Icons.chat, color: Colors.white),
              )
            : null,
      ),
    );
  }
}
