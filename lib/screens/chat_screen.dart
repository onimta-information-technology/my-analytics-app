import 'package:ballys_reservation_app/components/badge_service.dart';
import 'package:ballys_reservation_app/components/group_avatar.dart';
import 'package:ballys_reservation_app/components/group_details_sheet.dart';
import 'package:ballys_reservation_app/components/notification_banner.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/data/services/notification_store.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/models/chat_group.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/guest_booking_provider.dart';
import 'package:ballys_reservation_app/screens/chatDetail_screen.dart';
import 'package:ballys_reservation_app/utils/badge_sync_helper.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/mention_tracker.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
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
  List<ChatGroup> _groups = [];
  // Ids of every known group, used to keep group conversations out of the
  // 1:1 chat tabs.
  Set<String> _groupIds = {};
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isLoadingGroups = false;
  String? _groupsErrorMessage;
  String? _errorMessage;
  String? _currentUserName;
  String? _currentUserUuid;
  String? _selectedContactId;
  bool _hasProcessedNotification = false;

  /// Guards [_refreshGroupMentions]: chats and groups both trigger it, and the
  /// two refreshes often land together.
  bool _isScanningMentions = false;

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
      // An edit rewrites the chat's last-message preview, so the list is
      // pulled again even though nothing new was said.
      if (NotificationStore.isSilentThreadUpdate(message)) {
        _fetchChatsFromApiSilently();
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

        final String userIdentifier = await _resolveCurrentUserId();

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
                  currentUserName: _currentUserName,
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
        // Unread counts drive the "@" marker, so re-check it here too.
        unawaited(_refreshGroupMentions());
      }
      // Group tiles read their last-message preview from _groups, not
      // _contacts, so it must be refreshed here too or it goes stale.
      await _fetchGroupsSilently();
    } catch (e) {

    }
  }

  // Same as _fetchGroups but without the loading indicator, for push refreshes.
  Future<void> _fetchGroupsSilently() async {
    try {
      final groups = await FirebaseApiService.fetchUserGroups();

      if (!mounted) return;
      final parsed = groups.map(ChatGroup.fromApiJson).toList();
      setState(() {
        _groups = parsed;
        _groupIds = {
          for (final g in parsed) ...[g.groupId, g.id],
        }..removeWhere((id) => id.isEmpty);
      });
    } catch (e) {
      // Silent refresh: ignore errors, next manual refresh will retry.
    }
  }

  Future<void> _initializeData() async {
    await _getName();
    await _fetchChatsFromApi();
    await _fetchGroups();
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
      // Group pushes carry action == 'group_message'; the chatId is the group
      // id, not a 1:1 chat.
      final action = widget.notificationData!['action']?.toString();

      if (chatId != null && chatId.isNotEmpty) {
        _hasProcessedNotification = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openSpecificChat(
            chatId,
            senderName,
            senderId,
            isGroup: action == 'group_message',
          );
        });
      }
    }
  }

  ChatGroup? _groupForId(String chatId) => _groups.cast<ChatGroup?>().firstWhere(
        (group) => group?.groupId == chatId || group?.id == chatId,
        orElse: () => null,
      );

  void _openSpecificChat(
    String chatId,
    String? senderName,
    String? senderId, {
    bool isGroup = false,
  }) {
    // Groups live in their own list, so resolve them first. Otherwise the
    // senderName fallback below would open a 1:1 chat with whoever posted in
    // the group instead of the group itself.
    final group = _groupForId(chatId);
    if (group != null) {
      _openGroupChat(group);
      return;
    }

    if (isGroup) {
      // The group isn't in the cached list yet (just created/added). Refetch
      // and retry once rather than falling through to the personal-chat match.
      _fetchGroups().then((_) {
        if (!mounted) return;
        final refreshed = _groupForId(chatId);
        if (refreshed != null) {
          _openGroupChat(refreshed);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Group chat not found.'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
      return;
    }

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
            _refreshChatsAndGroups();
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
    // The chat backend keys users by device id, so keep it around to spot
    // "you" in member lists. Resolve it first and on its own: it is the only
    // reliable identifier, and a failing name lookup used to leave it null.
    await _resolveCurrentUserId();

    try {
      final userName = await FirebaseApiService.getName();
      if (!mounted) return;
      setState(() {
        _currentUserName = userName;
      });
    } catch (e) {

    }
  }

  /// Returns the device id the chat backend stores this user under.
  ///
  /// A push can trigger a refresh before [_getName] has run, and an identifier
  /// that matches no participant makes every row fall back to the first
  /// participant — often the current user, so the row showed the user's own
  /// name until a re-login refreshed the cache.
  Future<String> _resolveCurrentUserId() async {
    final cached = _currentUserUuid;
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final deviceId = await DeviceId.get();
      if (mounted) {
        setState(() {
          _currentUserUuid = deviceId;
        });
      } else {
        _currentUserUuid = deviceId;
      }
      return deviceId;
    } catch (e) {
      return '';
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

        final String userIdentifier = await _resolveCurrentUserId();

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
                  currentUserName: _currentUserName,
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
        unawaited(_refreshGroupMentions());
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

  /// Both lists feed the All/Unread tabs, so they refresh together.
  Future<void> _refreshChatsAndGroups() async {
    await Future.wait([_fetchChatsFromApi(), _fetchGroups()]);
  }

  Future<void> _fetchGroups() async {
    setState(() {
      _isLoadingGroups = true;
      _groupsErrorMessage = null;
    });

    try {
      final groups = await FirebaseApiService.fetchUserGroups();

      if (!mounted) return;
      final parsed = groups.map(ChatGroup.fromApiJson).toList();
      setState(() {
        _groups = parsed;
        _groupIds = {
          for (final g in parsed) ...[g.groupId, g.id],
        }..removeWhere((id) => id.isEmpty);
        _isLoadingGroups = false;
      });
      unawaited(_refreshGroupMentions());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _groupsErrorMessage = e.toString();
        _isLoadingGroups = false;
      });
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

  /// Group conversations also come back from /api/chats/user/:id, where the
  /// row carries no group name — it renders as whichever participant happens
  /// to be listed first. Those rows are dropped and the group is rendered from
  /// the groups API instead (chatUuid and groupId are the same value).
  ///
  /// Matching is by id only: a multi-participant chat the groups API does not
  /// know about still belongs in the list, so it keeps showing as a chat.
  bool _isGroupChat(ChatContact contact) =>
      _groupIds.contains(contact.chatUuid) || _groupIds.contains(contact.id);

  List<ChatContact> _oneToOneChats() =>
      _filteredContacts.where((c) => !_isGroupChat(c)).toList();

  /// Rows for the All/Unread tabs: 1:1 chats and groups interleaved, newest
  /// first. Entries are either a [ChatContact] or a [ChatGroup]; the group
  /// copies that the chats API also returns are dropped by [_oneToOneChats] so
  /// each conversation appears exactly once.
  List<Object> _getItemsForTab(int tabIndex) {
    // Tab 2 (Groups) is served by _buildGroupList from the groups API.
    if (tabIndex == 3) return const [];

    final bool unreadOnly = tabIndex == 1;

    final items = <Object>[
      ..._oneToOneChats().where((c) => !unreadOnly || c.unreadCount > 0),
      ..._filteredGroups.where(
        (g) => !unreadOnly || _unreadForGroup(g) > 0,
      ),
    ];

    items.sort((a, b) {
      final at = a is ChatContact
          ? a.lastMessageTime
          : _lastActivityForGroup(a as ChatGroup);
      final bt = b is ChatContact
          ? b.lastMessageTime
          : _lastActivityForGroup(b as ChatGroup);
      if (at == null && bt == null) return 0;
      // Conversations without a message yet sink to the bottom.
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    return items;
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
          lastMessageRead: _contacts[index].lastMessageRead,
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
            lastMessageRead: contact.lastMessageRead,
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
                // Both lists, not just chats: a message can have been
                // forwarded from this conversation into a group, and the
                // All/Unread tabs sort chats and groups together.
                _refreshChatsAndGroups();
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
                      Icon(
                        contact.lastMessageRead
                            ? Icons.done_all
                            : Icons.done,
                        color: contact.lastMessageRead
                            ? Colors.blue
                            : Colors.grey,
                        size: 16,
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  List<ChatGroup> get _filteredGroups {
    if (_searchQuery.isEmpty) return _groups;
    final query = _searchQuery.toLowerCase();
    return _groups
        .where(
          (group) =>
              group.groupName.toLowerCase().contains(query) ||
              group.lastMessage.toLowerCase().contains(query),
        )
        .toList();
  }

  /// The groups API carries no unread count, but the same conversation comes
  /// back from the chats API — borrow the count from there.
  int _unreadForGroup(ChatGroup group) => _chatRowForGroup(group)?.unreadCount ?? 0;

  /// Works out which groups have unread messages naming the user, so their row
  /// can show the "@" marker. Runs in the background after a list refresh: a
  /// group is only looked at while it has something unread, and only when its
  /// unread count or last message moved since the previous scan.
  Future<void> _refreshGroupMentions() async {
    if (_isScanningMentions || _groups.isEmpty) return;
    _isScanningMentions = true;

    try {
      final userUuid = await _resolveCurrentUserId();
      var changed = false;

      for (final group in List<ChatGroup>.from(_groups)) {
        if (!mounted) return;
        final unread = _unreadForGroup(group);
        final signature =
            '$unread|${_lastActivityForGroup(group)?.millisecondsSinceEpoch ?? 0}';
        final moved = await MentionTracker.refresh(
          chatId: group.groupId,
          signature: signature,
          hasUnread: unread > 0,
          currentUserUuid: userUuid,
        );
        changed = changed || moved;
      }

      if (changed && mounted) setState(() {});
    } finally {
      _isScanningMentions = false;
    }
  }

  ChatContact? _chatRowForGroup(ChatGroup group) {
    for (final contact in _contacts) {
      if (contact.chatUuid == group.groupId || contact.id == group.groupId) {
        return contact;
      }
    }
    return null;
  }

  /// Sort key for the merged list. A group with no messages yet has no
  /// lastMessageTime of its own, so fall back to the chats API row, which
  /// reports the creation time — that keeps a brand new group near the top
  /// instead of at the very bottom.
  DateTime? _lastActivityForGroup(ChatGroup group) =>
      group.lastMessageTime ?? _chatRowForGroup(group)?.lastMessageTime;

  Widget _buildGroupCard(ChatGroup group, FontSettings fontSettings) {
    final bool hasLastMessage = group.lastMessage.isNotEmpty;
    final int unreadCount = _unreadForGroup(group);
    // Unread messages in here name the user: the row gets the "@" marker,
    // which opens the conversation at the mention rather than at the end.
    final bool hasMentions = MentionTracker.hasMentions(group.groupId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: Colors.transparent,
      child: ListTile(
        leading: GroupAvatar(
          avatarUrl: group.groupAvatarUrl,
          radius: 25,
          backgroundColor: group.avatarColor,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                group.groupName,
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (group.isAdmin) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Admin',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontSize: fontSettings.fontSize - 6,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasLastMessage ? group.lastMessage : 'No messages yet',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: fontSettings.fontSize - 2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}'
              '${group.adminOnlyMessaging ? ' • Admins only' : ''}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: fontSettings.fontSize - 4,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              group.time,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: fontSettings.fontSize - 4,
              ),
            ),
            if (hasMentions || unreadCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasMentions) ...[
                      InkWell(
                        onTap: () => _openGroupChat(group, jumpToMentions: true),
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.alternate_email,
                            color: Colors.white,
                            size: fontSettings.fontSize - 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSettings.fontSize - 4,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            InkWell(
              onTap: () => _openGroupDetails(group, fontSettings),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
        onTap: () => _openGroupChat(group),
        onLongPress: () => _openGroupDetails(group, fontSettings),
      ),
    );
  }

  void _openGroupDetails(ChatGroup group, FontSettings fontSettings) {
    showGroupDetailsSheet(
      context: context,
      groupId: group.groupId,
      avatarColor: group.avatarColor,
      fontSettings: fontSettings,
      currentUserUuid: _currentUserUuid,
      // A rename or member change shows up in the list straight away.
      onGroupChanged: _fetchGroups,
    );
  }

  /// Opens the group conversation. The group chat reuses the 1:1 screen with
  /// the groupId standing in for the chatId, which is how the backend models
  /// group messages too.
  /// [jumpToMentions] opens the conversation on the oldest unread message
  /// naming the user — what tapping the "@" marker does — instead of at the
  /// end of the conversation.
  void _openGroupChat(ChatGroup group, {bool jumpToMentions = false}) {
    final groupContact = ChatContact(
      id: group.groupId,
      chatUuid: group.groupId,
      userUuid: group.groupId,
      name: group.groupName,
      firstName: group.groupName,
      lastMessage: group.lastMessage,
      time: group.time,
      avatarColor: group.avatarColor,
      initials: group.initials,
      participants: const [],
      createdAt: DateTime.now(),
      lastMessageSenderName: group.lastMessageSender,
      appType: FirebaseApiService.appType,
      avatarUrl: group.groupAvatarUrl,
    );

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => IndividualChatScreen(
              contact: groupContact,
              isGroup: true,
              groupMemberCount: group.memberCount,
              canSendMessages: !group.adminOnlyMessaging || group.isAdmin,
              // Carried either way, so the "@" button inside the chat can
              // walk the unread mentions even when the row itself was tapped.
              mentionMessageIds: MentionTracker.mentionsIn(group.groupId),
              jumpToMentionOnOpen: jumpToMentions,
            ),
          ),
        )
        // Forwarding out of a group updates 1:1 chats too, so refresh both.
        .then((_) => _refreshChatsAndGroups());
  }

  Widget _buildGroupList(FontSettings fontSettings) {
    if (_isLoadingGroups && _groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Loading groups...',
              style: TextStyle(fontSize: fontSettings.fontSize - 2),
            ),
          ],
        ),
      );
    }

    if (_groupsErrorMessage != null && _groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _groupsErrorMessage!,
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchGroups,
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

    final groups = _filteredGroups;

    if (groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchGroups,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            const Icon(Icons.groups_outlined, size: 50, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No groups yet',
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _showNewGroupSheet(fontSettings),
                child: Text(
                  'Create a group',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: fontSettings.fontSize - 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchGroups,
      child: ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) =>
            _buildGroupCard(groups[index], fontSettings),
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

    final items = _getItemsForTab(tabIndex);

    if (items.isEmpty) {
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
              onPressed: _refreshChatsAndGroups,
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
      onRefresh: _refreshChatsAndGroups,
      child: GestureDetector(
        onTap: () {
          if (_selectedContactId != null) {
            setState(() {
              _selectedContactId = null;
            });
          }
        },
        child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return item is ChatGroup
                ? _buildGroupCard(item, fontSettings)
                : _buildContactCard(item as ChatContact, fontSettings);
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
              onPressed: () {
                _fetchChatsFromApi();
                _fetchGroups();
              },
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
                  _buildGroupList(fontSettings),
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
                onPressed: () => _showNewConversationOptions(fontSettings),
                child: const Icon(Icons.chat, color: Colors.white),
              )
            : null,
      ),
    );
  }

  /// Lets the user pick between a 1:1 chat and a group before loading contacts.
  void _showNewConversationOptions(FontSettings fontSettings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.person_add, color: Colors.white),
                ),
                title: Text(
                  'New Chat',
                  style: TextStyle(
                    fontSize: fontSettings.fontSize,
                    fontWeight: fontSettings.fontWeight,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showNewChatSheet(fontSettings);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.group_add, color: Colors.white),
                ),
                title: Text(
                  'New Group',
                  style: TextStyle(
                    fontSize: fontSettings.fontSize,
                    fontWeight: fontSettings.fontWeight,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showNewGroupSheet(fontSettings);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showNewChatSheet(FontSettings fontSettings) async {
    await _fetchAllUsersForNewChat();

    if (!mounted) return;

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
                                                      lastMessageRead: contact
                                                          .lastMessageRead,
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

                                                    _refreshChatsAndGroups();
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
                                                      lastMessageRead: contact
                                                          .lastMessageRead,
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
  }

  Future<void> _showNewGroupSheet(FontSettings fontSettings) async {
    await _fetchAllUsersForNewChat();

    if (!mounted) return;

    final nameController = TextEditingController();
    // Keyed by userUuid so the selection survives search filtering.
    final Map<String, ChatContact> selectedMembers = {};
    List<ChatContact> visibleUsers = List.from(_allUsers);
    // Optional group avatar, uploaded in the same multipart create call.
    File? avatarFile;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final bool canCreate =
                nameController.text.trim().isNotEmpty &&
                selectedMembers.isNotEmpty;

            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  height: MediaQuery.of(context).size.height * 0.85,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "New Group",
                        style: TextStyle(
                          fontSize: fontSettings.fontSize + 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await _pickGroupAvatar(sheetContext);
                            if (picked != null) {
                              setModalState(() => avatarFile = picked);
                            }
                          },
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: avatarFile != null
                                    ? FileImage(avatarFile!)
                                    : null,
                                child: avatarFile == null
                                    ? Icon(
                                        Icons.group,
                                        size: 44,
                                        color: Colors.grey[600],
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        style: TextStyle(fontSize: fontSettings.fontSize - 2),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: "Group name",
                          hintStyle: TextStyle(
                            fontSize: fontSettings.fontSize - 2,
                          ),
                          prefixIcon: const Icon(Icons.group),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                        ),
                        // Rebuild so the create button enables as soon as the
                        // name stops being blank.
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        style: TextStyle(fontSize: fontSettings.fontSize - 2),
                        decoration: InputDecoration(
                          hintText: "Search contacts...",
                          hintStyle: TextStyle(
                            fontSize: fontSettings.fontSize - 2,
                          ),
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
                              visibleUsers = List.from(_allUsers);
                            } else {
                              visibleUsers = _allUsers
                                  .where(
                                    (user) =>
                                        user.name.toLowerCase().contains(
                                          query.toLowerCase(),
                                        ) ||
                                        user.firstName.toLowerCase().contains(
                                          query.toLowerCase(),
                                        ),
                                  )
                                  .toList();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedMembers.isEmpty
                            ? "Select members"
                            : "${selectedMembers.length} member${selectedMembers.length == 1 ? '' : 's'} selected",
                        style: TextStyle(
                          fontSize: fontSettings.fontSize - 3,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (selectedMembers.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: selectedMembers.values
                                .map(
                                  (member) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Chip(
                                      backgroundColor: Colors.green.withOpacity(
                                        0.1,
                                      ),
                                      label: Text(
                                        member.name,
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize - 5,
                                        ),
                                      ),
                                      onDeleted: () => setModalState(() {
                                        selectedMembers.remove(member.userUuid);
                                      }),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Expanded(
                        child: _allUsers.isEmpty
                            ? Center(
                                child: Text(
                                  'No contacts available',
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize - 2,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: visibleUsers.length,
                                itemBuilder: (context, index) {
                                  final contact = visibleUsers[index];
                                  final bool isSelected = selectedMembers
                                      .containsKey(contact.userUuid);

                                  return CheckboxListTile(
                                    value: isSelected,
                                    activeColor: Colors.green,
                                    controlAffinity:
                                        ListTileControlAffinity.trailing,
                                    onChanged: (checked) {
                                      setModalState(() {
                                        if (checked == true) {
                                          selectedMembers[contact.userUuid] =
                                              contact;
                                        } else {
                                          selectedMembers.remove(
                                            contact.userUuid,
                                          );
                                        }
                                      });
                                    },
                                    secondary: CircleAvatar(
                                      backgroundColor: contact.avatarColor,
                                      child: Text(
                                        contact.initials,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: fontSettings.fontSize - 4,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      contact.name,
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight,
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
                                          contact.isOnline
                                              ? "Online"
                                              : "Offline",
                                          style: TextStyle(
                                            color: contact.isOnline
                                                ? Colors.green[700]
                                                : Colors.grey,
                                            fontSize: fontSettings.fontSize - 4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize - 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: canCreate
                                  ? () {
                                      Navigator.pop(sheetContext);
                                      _createGroup(
                                        nameController.text.trim(),
                                        selectedMembers.values.toList(),
                                        avatarPath: avatarFile?.path,
                                      );
                                    }
                                  : null,
                              child: Text(
                                "Create Group",
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize - 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  /// Lets the user pick a group avatar from the camera or gallery.
  Future<File?> _pickGroupAvatar(BuildContext sheetContext) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: sheetContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;

    try {
      // Downscaled before upload — the backend caps the avatar at 5MB.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      return picked == null ? null : File(picked.path);
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _createGroup(
    String name,
    List<ChatContact> members, {
    String? avatarPath,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Creating group...'),
          ],
        ),
        duration: Duration(seconds: 30),
        backgroundColor: Colors.blue,
      ),
    );

    final groupId = await FirebaseApiService.createGroup(
      name: name,
      members: members,
      avatarPath: avatarPath,
    );

    scaffoldMessenger.hideCurrentSnackBar();

    if (groupId != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Group "$name" created'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      await _fetchGroups();

      if (!mounted) return;
      // Jump to the Groups tab so the new group is visible right away.
      _tabController.animateTo(2);
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to create group'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
