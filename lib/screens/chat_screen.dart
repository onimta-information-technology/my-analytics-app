import 'package:ballys_reservation_app/components/badge_service.dart';
import 'package:ballys_reservation_app/components/notification_banner.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/guest_booking_provider.dart';
import 'package:ballys_reservation_app/screens/chatDetail_screen.dart';
import 'package:ballys_reservation_app/utils/badge_sync_helper.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';

List<ChatContact> _filteredUsers = [];

class ChatScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? notificationData;
  const ChatScreen({super.key, this.notificationData});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver,ConnectivityMixin {
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

  // Add message subscription
  StreamSubscription<RemoteMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _initializeData();
    _setupNotificationListener();
    _syncBadgeCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Refresh when app comes to foreground
      _fetchChatsFromApi();
      BadgeService().clearBadge();
    } else if (state == AppLifecycleState.paused) {
      // Update badge when app goes to background
      final unreadCount = _getTotalUnreadCount();
      BadgeService().updateBadge(unreadCount);
    }
  }

  int _getTotalUnreadCount() {
    return _contacts.fold(0, (sum, contact) => sum + contact.unreadCount);
  }

  Future<void> _syncBadgeCount() async {
    try {
      final unreadCount = _getTotalUnreadCount();
      await BadgeService().updateBadge(unreadCount);
    
      // Then sync with server for accuracy
      await BadgeSyncHelper.syncBadgeWithServer();
    } catch (e) {

    }
  }
Future<void> _reloadGuestBookings() async {
  try {
    final container = ProviderScope.containerOf(context);
    await container.read(guestBookingProvider.notifier).getAllBookings();
  } catch (e) {
    print('Error reloading guest bookings: $e');
  }
}
//   void _setupNotificationListener() {
//   _messageSubscription = FirebaseMessaging.onMessage.listen((
//     RemoteMessage message,
//   ) {
//     if (message.data['msg_type'] == '35') {
//       _reloadGuestBookings();
//       return;
//     }

//     // Extract chatId from Details field as well
//     String? chatId = message.data['chatId'] ?? message.data['chat_id'];
//     final detailsJson = message.data['Details'];
//     if ((chatId == null || chatId.isEmpty) && detailsJson != null) {
//       try {
//         final details = jsonDecode(detailsJson);
//         chatId = details['chatId']?.toString();
//       } catch (_) {}
//     }

//     if (message.data['msg_type'] == '11' ||
//         message.data['type'] == 'chat' ||
//         message.data.containsKey('Details') ||
//         chatId != null) {
//       _fetchChatsFromApiSilently();
//     }
//   });
// }
  void _setupNotificationListener() {
    // Listen for foreground messages
    _messageSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      
if (message.data['msg_type'] == '35') {
      _reloadGuestBookings();
      return;
    }
      // Check if it's a chat notification
      if (message.data['msg_type'] == '11' ||
          message.data['type'] == 'chat' ||
          message.data.containsKey('Details')) {
        // Refresh silently without showing loading indicator
        _fetchChatsFromApiSilently();
      }
    });
  }
  // Silent refresh - no loading indicator
  Future<void> _fetchChatsFromApiSilently() async {
    try {
      final chatData = await FirebaseApiService.fetchUserChats();
      final userData = await FirebaseApiService.fetchAllUsers();

      if (chatData['chats'] != null) {
        final List<dynamic> chats = chatData['chats'];

        // Extract the actual device ID from the first chat's participants
        String? actualDeviceId;
        if (chats.isNotEmpty && _currentUserName != null) {
          final firstChat = chats[0];
          final participants =
              firstChat['participants'] as List<dynamic>? ?? [];

          for (var participant in participants) {
            final uuid = participant['user_uuid'] as String?;
            final name = participant['name'] as String?;

            if (name == _currentUserName && uuid != null && uuid != name) {
              actualDeviceId = uuid;
              break;
            }
          }
        }

        final String userIdentifier = actualDeviceId ?? _currentUserName ?? '';

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
                  userIdentifier,
                  participantDetails: userDetailsMap,
                ),
              )
              .toList();
          _filteredContacts = List.from(_contacts);
        });

        await _saveChats();
        // Update badge with total unread count
        final unreadCount = _getTotalUnreadCount();
        await BadgeService().updateBadge(unreadCount);
    
      }
    } catch (e) {
   
    }
  }

  Future<void> _initializeData() async {
    await _getName();
    await _fetchChatsFromApi();
    _checkAndOpenNotificationChat();
    // Sync badge after fetching chats
    await _syncBadgeCount();
  }

  void _checkAndOpenNotificationChat() {
    if (_hasProcessedNotification) return;

    if (widget.notificationData != null &&
        widget.notificationData!['openChat'] == true) {
      final chatId = widget.notificationData!['chatId'] as String?;
      final senderName = widget.notificationData!['senderName'] as String?;
      final senderId = widget.notificationData!['senderId'] as String?;

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
     
    }
  }

  void _showDeleteConfirmation(ChatContact contact) {
    final fontSettings = ref.read(fontSettingsProvider);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Chat',
            style: TextStyle(
              fontSize: fontSettings.fontSize + 2,
              fontWeight: fontSettings.fontWeight,
            ),
          ),
          content: Text(
            'Are you sure you want to delete the chat with ${contact.name}?',
            style: TextStyle(fontSize: fontSettings.fontSize - 2),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(fontSize: fontSettings.fontSize - 2),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _selectedContactId = null;
                });
              },
            ),
            TextButton(
              child: Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: fontSettings.fontSize - 2,
                ),
              ),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                navigator.pop();

                // Clear selection FIRST
                setState(() {
                  _selectedContactId = null;
                });

                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Text('Deleting chat...'),
                      ],
                    ),
                    duration: Duration(seconds: 30),
                    backgroundColor: Colors.orange,
                  ),
                );



                final success = await FirebaseApiService.deleteChat(
                  contact.chatUuid,
                );

                scaffoldMessenger.hideCurrentSnackBar();

                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Chat deleted successfully. Refreshing...'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );

                  // Wait a moment for backend to process
                  await Future.delayed(const Duration(milliseconds: 500));

                  // Refresh from API
                  await _fetchChatsFromApi();

                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete chat'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchChatsFromApi() async {
    bool showLoading = !_isLoading;

    setState(() {
      if (showLoading) _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final chatData = await FirebaseApiService.fetchUserChats();
      final userData = await FirebaseApiService.fetchAllUsers();

      if (chatData['chats'] != null) {
        final List<dynamic> chats = chatData['chats'];

        // Extract the actual device ID from the first chat's participants
        String? actualDeviceId;
        if (chats.isNotEmpty && _currentUserName != null) {
          final firstChat = chats[0];
          final participants =
              firstChat['participants'] as List<dynamic>? ?? [];

          for (var participant in participants) {
            final uuid = participant['user_uuid'] as String?;
            final name = participant['name'] as String?;

            // Find the participant with matching name to get the real device ID
            if (name == _currentUserName && uuid != null && uuid != name) {
              actualDeviceId = uuid;
              break;
            }
          }
        }

        // Use the actual device ID if found, otherwise fall back to current user name
        final String userIdentifier = actualDeviceId ?? _currentUserName ?? '';

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
                  userIdentifier,
                  participantDetails: userDetailsMap,
                ),
              )
              .toList();
          _filteredContacts = List.from(_contacts);
          if (showLoading) _isLoading = false;
        });
        await _saveChats();
        // Update badge with total unread count
        final unreadCount = _getTotalUnreadCount();
        await BadgeService().updateBadge(unreadCount);
      } else {
        setState(() {
          _errorMessage = 'No chats data received';
          if (showLoading) _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        if (showLoading) _isLoading = false;
      });

      await _loadChats();
    }
  }

  // Rest of the methods remain the same...
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
            lastMessageSenderName: null,
            appType: ChatContact.parseAppType(user['appType']),
          );
        }).toList();

        setState(() {
          _allUsers = userContacts;
          _filteredUsers = List.from(userContacts);
        });
      }
    } catch (e) {
    
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
          userUuid: _contacts[index].userUuid,
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
          lastMessageSenderName: _contacts[index].lastMessageSenderName,
          appType: _contacts[index].appType,
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

  Widget _buildContactCard(ChatContact contact, FontSettings fontSettings) {
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

          final chatId = await FirebaseApiService.createChat(contact.userUuid);

          final contactWithChatId = ChatContact(
            id: contact.id,
            chatUuid: chatId ?? contact.chatUuid,
            userUuid: contact.userUuid,
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
            lastMessageSenderName: contact.lastMessageSenderName,
            appType: contact.appType,
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSettings.fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
             if (contact.isOnline)
  Positioned(
    bottom: 0,
    right: 0,
    child: Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFF00E676), // bright greenAccent shade
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    ),
  ),
            ],
          ),
          title: Text(
            contact.name,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasLastMessage) ...[
                Text(
                  contact.lastMessage,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: fontSettings.fontSize - 2,
                    fontWeight: contact.unreadCount > 0
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (contact.lastMessageSender != null)
                  Text(
                    'by ${contact.lastMessageSenderName}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: fontSettings.fontSize - 4,
                    ),
                  ),
              ] else
                Text(
                  'No messages yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: fontSettings.fontSize - 2,
                  ),
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
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: fontSettings.fontSize - 4,
                      ),
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSettings.fontSize - 4,
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

  Widget _buildChatList(int tabIndex, FontSettings fontSettings) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Loading chats...',
              style: TextStyle(fontSize: fontSettings.fontSize - 2),
            ),
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
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchChatsFromApi,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSettings.fontSize - 2,
                ),
              ),
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
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _fetchChatsFromApi,
              child: Text(
                "Refresh chats",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: fontSettings.fontSize - 2,
                ),
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
            return _buildContactCard(contacts[index], fontSettings);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text(_selectedContactId != null ? "Select action" : "Chats"),
              Text(
                "Chats",
                style: TextStyle(
                  fontSize: fontSettings.fontSize + 2,
                  fontWeight: fontSettings.fontWeight,
                ),
              ),
              // Text(
              //   _selectedContactId != null
              //       ? "1 selected"
              //       : "${_contacts.length} conversations",
              //   style: const TextStyle(
              //     fontSize: 12,
              //     fontWeight: FontWeight.normal,
              //   ),
              // ),
            ],
          ),
          // backgroundColor: _selectedContactId != null
          //     ? Colors.red
          //     : Colors.green,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          // leading: _selectedContactId != null
          //     ? IconButton(
          //         icon: const Icon(Icons.close),
          //         onPressed: () {
          //           setState(() {
          //             _selectedContactId = null;
          //           });
          //         },
          //       )
          //     : null,
          // actions: _selectedContactId != null
          //     ? [
          //         IconButton(
          //           icon: const Icon(Icons.delete),
          //           onPressed: () {
          //             final contact = _contacts.firstWhere(
          //               (c) => c.id == _selectedContactId,
          //             );
          //             _showDeleteConfirmation(contact);
          //           },
          //         ),
          //       ]
          actions: [
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      onChanged: _filterContacts,
                      style: TextStyle(fontSize: fontSettings.fontSize - 2),
                      decoration: InputDecoration(
                        hintText: "Search chats...",
                        hintStyle: TextStyle(
                          fontSize: fontSettings.fontSize - 2,
                        ),
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
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.green,
                    labelColor: Colors.green,
                    unselectedLabelColor: Colors.black54,
                    labelStyle: TextStyle(
                      fontSize: fontSettings.fontSize - 4,
                      fontWeight: fontSettings.fontWeight,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: fontSettings.fontSize - 4,
                    ),
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
        body: Column(
          children: [
            const NotificationBanner(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChatList(0, fontSettings),
                  _buildChatList(1, fontSettings),
                  _buildChatList(2, fontSettings),
                  _buildChatList(3, fontSettings),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSettings.fontSize - 4,
                    ),
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
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize - 2,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "Search contacts...",
                                      hintStyle: TextStyle(
                                        fontSize: fontSettings.fontSize - 2,
                                      ),
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
                                  Text(
                                    "Start New Chat",
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize + 2,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: _allUsers.isEmpty
                                        ? Center(
                                            child: Text(
                                              'No contacts available',
                                              style: TextStyle(
                                                fontSize:
                                                    fontSettings.fontSize - 2,
                                              ),
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
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: fontSettings
                                                              .fontSize -
                                                          4,
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  contact.name,
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    fontWeight:
                                                        fontSettings.fontWeight,
                                                  ),
                                                ),
                                                subtitle: Row(
  children: [
    Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: contact.isOnline
            ? const Color(0xFF00E676)
            : Colors.grey,
        shape: BoxShape.circle,
      ),
    ),
    const SizedBox(width: 6),
    Text(
      contact.isOnline ? "Online" : "Offline",
      style: TextStyle(
        color: contact.isOnline ? Colors.green[700] : Colors.grey,
        fontSize: fontSettings.fontSize - 4,
      ),
    ),
  ],
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
                                                          contact.userUuid,
                                                        );

                                                    scaffoldMessenger
                                                        .hideCurrentSnackBar();

                                                    final contactWithChatId = ChatContact(
                                                      id: contact.id,
                                                      chatUuid:
                                                          chatId ??
                                                          contact.chatUuid,
                                                      userUuid:
                                                          contact.userUuid,
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
                                                      lastMessageSenderName: contact
                                                          .lastMessageSenderName,
                                                      appType: contact.appType,
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
                                                    scaffoldMessenger.showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Error creating chat: $e',
                                                        ),
                                                        backgroundColor:
                                                            Colors.orange,
                                                      ),
                                                    );

                                                    final contactWithChatId = ChatContact(
                                                      id: contact.id,
                                                      chatUuid:
                                                          contact.chatUuid,
                                                      userUuid:
                                                          contact.userUuid,
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
                                                      lastMessageSenderName: contact
                                                          .lastMessageSenderName,
                                                      appType: contact.appType,
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
                                    child: Text(
                                      "Close",
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize - 2,
                                      ),
                                    ),
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
