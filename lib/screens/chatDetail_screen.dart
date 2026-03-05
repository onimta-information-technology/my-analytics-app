import 'dart:async';
import 'dart:convert';
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
  bool _isUploading = false;

  Timer? _readStatusPollTimer;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fetchMessagesFromApi(silent: true);
      BadgeService().clearBadge();
    }
  }

  // ─── Setup ─────────────────────────────────────────────────────────────────

  void _startReadStatusPolling() {
    _readStatusPollTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _fetchMessagesFromApi(silent: true, updateReadStatusOnly: true);
      }
    });
  }

  void _onFocusChange() {
    if (_messageFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToBottom();
      });
    }
  }

//   void _setupForegroundMessageListener() {
//   _foregroundMessageSubscription =
//       FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    
//     // DEBUG - remove after fixing
//     print('📩 ChatDetail received message: ${message.data}');
//     print('📩 msg_type: ${message.data['msg_type']}');
//     print('📩 current chatUuid: ${widget.contact.chatUuid}');

//     final msgType = message.data['msg_type']?.toString().trim() ?? 
//                     message.data['type']?.toString().trim();

//     // Skip guest booking notifications
//     if (msgType == '35') return;

//     // Extract chatId from top-level fields
//     String? chatId = message.data['chatId']?.toString() ??
//         message.data['chat_id']?.toString() ??
//         message.data['ChatId']?.toString() ??
//         message.data['Chat_Id']?.toString();

//     // Extract chatId from Details JSON field
//     final detailsJson = message.data['Details'];
//     if ((chatId == null || chatId.isEmpty) && 
//          detailsJson != null && detailsJson.isNotEmpty) {
//       try {
//         final details = jsonDecode(detailsJson);
//         chatId = details['chatId']?.toString() ??
//                  details['chat_id']?.toString();
//         print('📩 chatId from Details: $chatId');
//       } catch (e) {
//         print('📩 Error parsing Details: $e');
//       }
//     }

//     print('📩 resolved chatId: $chatId');
//     print('📩 match: ${chatId == widget.contact.chatUuid}');

//     // Refresh if it's any chat message type
//     final bool isChatMessage = msgType == '11' ||
//         msgType == 'chat' ||
//         message.data.containsKey('Details') ||
//         message.data.containsKey('message') ||
//         chatId != null;

//     if (isChatMessage) {
//       if (chatId == null ||
//           chatId.isEmpty ||
//           chatId == widget.contact.chatUuid) {
//         print('✅ Refreshing messages for chat: ${widget.contact.chatUuid}');
//         _fetchMessagesFromApi(silent: true);
//       } else {
//         print('⛔ chatId mismatch — skipping refresh');
//         print('   incoming: $chatId');
//         print('   current:  ${widget.contact.chatUuid}');
//       }
//     }
//   });
// }
void _setupForegroundMessageListener() {
    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final chatId = message.data['chatId'] ??
          message.data['chat_id'] ??
          message.data['ChatId'] ??
          message.data['Chat_Id'];
      final msgType = message.data['msg_type'] ?? message.data['type'];
      final bool isChatMessage = msgType == '11' ||
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
      setState(() => _currentUserName = userName);
    } catch (_) {}
  }

  // ─── Fetch messages ─────────────────────────────────────────────────────────

  Future<void> _fetchMessagesFromApi({
    bool silent = false,
    bool updateReadStatusOnly = false,
  }) async {
    if (_isLoadingMessages && !silent) return;
    if (!silent && !updateReadStatusOnly) {
      setState(() => _isLoadingMessages = true);
    }

    try {
      final response =
          await FirebaseApiService.fetchMessages(widget.contact.chatUuid);
      final deviceId = await DeviceId.get();

      if (response['success'] == true && response['data'] != null) {
        final rd = response['data'];
        if (rd['success'] == true && rd['messages'] != null) {
          final List<dynamic> raw = rd['messages'];

          // Build flat list then group consecutive images into grid bubbles
          final flat = raw
              .map((j) =>
                  ChatMessage.fromApiResponse(j, deviceId ?? ''))
              .toList();
          final grouped = ChatMessage.groupImageMessages(flat);

          if (updateReadStatusOnly) {
            bool changed = false;
            for (int i = 0; i < _messages.length; i++) {
              final updated = grouped.firstWhere(
                (m) => m.apiMessageId == _messages[i].apiMessageId,
                orElse: () => _messages[i],
              );
              if (_messages[i].isRead != updated.isRead) {
                changed = true;
                _messages[i] = updated;
              }
            }
            if (changed && mounted) setState(() {});
          } else {
            final hadMessages = _messages.isNotEmpty;
            final countChanged = _messages.length != grouped.length;
            setState(() {
              _messages = grouped;
              if (!silent) _isLoadingMessages = false;
            });
            await _markMessagesAsRead();
            if (!hadMessages || (!silent && countChanged)) {
              await Future.delayed(const Duration(milliseconds: 100));
              _scrollToBottom();
            }
          }
        } else {
          if (!silent && !updateReadStatusOnly) {
            setState(() => _isLoadingMessages = false);
          }
        }
      }
    } catch (_) {
      if (!silent && !updateReadStatusOnly) {
        setState(() => _isLoadingMessages = false);
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      if (_currentUserName == null || _messages.isEmpty) return;
      final ids = _messages
          .where((m) => !m.isMe && m.apiMessageId != null)
          .map((m) => m.apiMessageId!)
          .toList();
      if (ids.isEmpty) return;
      await FirebaseApiService.markMessagesAsRead(
          widget.contact.chatUuid, ids);
    } catch (_) {}
  }

  // ─── Send text ──────────────────────────────────────────────────────────────

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    setState(() {
      _messages.add(ChatMessage(
        id: localId,
        text: text,
        isMe: true,
        timestamp: now,
        isRead: false,
      ));
    });
    _messageController.clear();
    if (widget.onMessageSent != null) widget.onMessageSent!(text);

    try {
      final response = await FirebaseApiService.sendMessage(
        recipientUuid: widget.contact.userUuid,
        message: text,
        title: _currentUserName ?? '',
        body: text,
        chatId: widget.contact.chatUuid,
      );
      if (response['success'] == true) {
        final rd = response['data'];
        if (rd != null && rd['success'] == true && rd['data'] != null) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == localId);
            if (idx != -1) {
              _messages[idx] = _messages[idx].copyWith(
                apiMessageId: rd['data']['messageId'],
                apiChatId: rd['data']['chatId'],
                isRead: false,
              );
            }
          });
        }
      } else {
        _showErrorSnack('Failed to send message. Please try again.');
      }
    } catch (_) {
      _showErrorSnack('Error sending message.');
    }
  }

  // ─── Upload files ───────────────────────────────────────────────────────────

  Future<void> _uploadAndSendFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    final now = DateTime.now();
    final localId = now.millisecondsSinceEpoch.toString();

    // Determine which files are images
    final imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
    final localItems = filePaths.map((p) {
      final ext = p.split('.').last.toLowerCase();
      return AttachmentItem(
        localPath: p,
        fileName: p.split('/').last,
        mimeType: imageExts.contains(ext) ? 'image/$ext' : null,
      );
    }).toList();

    final allImages = localItems.every((a) => a.isImage);

    setState(() {
      _isUploading = true;
      if (allImages && localItems.length > 1) {
        // Single grouped bubble for multiple images
        _messages.add(ChatMessage(
          id: localId,
          text: '',
          isMe: true,
          timestamp: now,
          isRead: false,
          groupedAttachments: localItems,
        ));
      } else {
        // One bubble per file (or single image)
        for (int i = 0; i < localItems.length; i++) {
          final item = localItems[i];
          final ext =
              (item.localPath ?? '').split('.').last.toLowerCase();
          _messages.add(ChatMessage(
            id: '${localId}_$i',
            text: item.fileName ?? '',
            isMe: true,
            timestamp: now,
            isRead: false,
            filePath: item.localPath,
            fileType: item.isImage ? 'image' : 'document',
            fileName: item.fileName,
            groupedAttachments: item.isImage ? [item] : [],
          ));
        }
      }
    });
    _scrollToBottom();

    try {
      final result = await FirebaseApiService.uploadFiles(
        chatId: widget.contact.chatUuid,
        filePaths: filePaths,
      );

      if (result['success'] == true) {
        final files =
            (result['data']['files'] as List<dynamic>?) ?? [];

        setState(() {
          if (allImages && localItems.length > 1) {
            // Update the single grouped bubble
            final idx =
                _messages.indexWhere((m) => m.id == localId);
            if (idx != -1) {
              final updatedItems = <AttachmentItem>[];
              for (int i = 0; i < localItems.length; i++) {
                final f = i < files.length
                    ? files[i] as Map<String, dynamic>
                    : <String, dynamic>{};
                updatedItems.add(localItems[i].copyWith(
                  url: f['url'] as String?,
                  messageId: f['messageId'] as String?,
                  mimeType: f['type'] as String?,
                  fileName: f['filename'] as String?,
                ));
              }
              _messages[idx] = _messages[idx].copyWith(
                apiMessageId: files.isNotEmpty
                    ? files[0]['messageId'] as String?
                    : null,
                apiChatId: widget.contact.chatUuid,
                groupedAttachments: updatedItems,
                isRead: false,
              );
            }
          } else {
            // Update individual bubbles
            for (int i = 0; i < filePaths.length; i++) {
              final bubbleId = '${localId}_$i';
              final idx =
                  _messages.indexWhere((m) => m.id == bubbleId);
              if (idx != -1 && i < files.length) {
                final f = files[i] as Map<String, dynamic>;
                final mime = f['type'] as String? ?? '';
                final isImg = mime.startsWith('image/');
                _messages[idx] = _messages[idx].copyWith(
                  apiMessageId: f['messageId'] as String?,
                  apiChatId: widget.contact.chatUuid,
                  attachmentUrl: f['url'] as String?,
                  attachmentType: mime,
                  fileType: isImg ? 'image' : 'document',
                  fileName: f['filename'] as String?,
                  groupedAttachments: isImg
                      ? [
                          AttachmentItem(
                            url: f['url'] as String?,
                            mimeType: mime,
                            fileName: f['filename'] as String?,
                            messageId: f['messageId'] as String?,
                          )
                        ]
                      : [],
                  isRead: false,
                );
              }
            }
          }
          _isUploading = false;
        });

        if (widget.onMessageSent != null) {
          widget.onMessageSent!(
              '📎 ${filePaths.length} file(s) sent');
        }
      } else {
        setState(() => _isUploading = false);
        _showErrorSnack(
            'Upload failed: ${result['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _showErrorSnack('Upload error: $e');
    }
  }

  // ─── Pickers ────────────────────────────────────────────────────────────────

  void _onCameraPressed() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
          source: ImageSource.camera, imageQuality: 80);
      if (photo != null) await _uploadAndSendFiles([photo.path]);
    } catch (e) {
      _showErrorSnack('Error taking photo: $e');
    }
  }

  void _onAttachFilePressed() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.blue),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImagesFromGallery();
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.insert_drive_file, color: Colors.orange),
            title: const Text('Document'),
            onTap: () {
              Navigator.pop(ctx);
              _pickDocuments();
            },
          ),
          ListTile(
            leading: const Icon(Icons.cancel, color: Colors.red),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(ctx),
          ),
        ]),
      ),
    );
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final List<XFile> images =
          await _imagePicker.pickMultiImage(imageQuality: 80);
      if (images.isNotEmpty) {
        await _uploadAndSendFiles(images.map((x) => x.path).toList());
      }
    } catch (e) {
      _showErrorSnack('Error selecting image: $e');
    }
  }

  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'
        ],
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final paths = result.files
            .map((f) => f.path!)
            .where((p) => p.isNotEmpty)
            .toList();
        await _uploadAndSendFiles(paths);
      }
    } catch (e) {
      _showErrorSnack('Error selecting document: $e');
    }
  }

  // ─── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _deleteMessageFromApi(
      String chatId, String messageId) async {
    final response =
        await FirebaseApiService.softDeleteMessage(chatId, messageId);
    if (response['success'] != true) {
      _showErrorSnack('Could not delete message.');
    }
  }

  void _deleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content:
            const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final msg =
                  _messages.firstWhere((m) => m.id == messageId);
              if (msg.apiChatId != null && msg.apiMessageId != null) {
                await _deleteMessageFromApi(
                    msg.apiChatId!, msg.apiMessageId!);
              }
              setState(() {
                _messages.removeWhere((m) => m.id == messageId);
                _selectedMessageId = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Message deleted'),
                duration: Duration(seconds: 2),
              ));
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  void _showErrorSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  String _formatTime(DateTime ts) => DateFormat('HH:mm').format(ts);

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('d MMMM yyyy').format(date);
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    final cur = _messages[index];
    final prev = _messages[index - 1];
    return DateTime(cur.timestamp.year, cur.timestamp.month,
            cur.timestamp.day) !=
        DateTime(prev.timestamp.year, prev.timestamp.month,
            prev.timestamp.day);
  }

  // ─── Image grid widget (WhatsApp-style) ─────────────────────────────────────

  /// Renders up to 4 cells in a 2×2 grid with "+N" overlay on the last cell.
  Widget _buildImageGrid(
      List<AttachmentItem> items, bool isMe, String messageId) {
    const double gridSize = 220.0; // total grid width
    const double gap = 3.0;
    const double cellSize = (gridSize - gap) / 2;

    // Show max 4 cells; last cell may show "+N more" overlay
    final displayCount = items.length > 4 ? 4 : items.length;
    final extraCount = items.length - 4;

    Widget buildCell(int index, {bool showOverlay = false}) {
      final item = items[index];
      Widget img;

      if (item.url != null && item.url!.isNotEmpty) {
        img = Image.network(
          item.url!,
          width: cellSize,
          height: cellSize,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              width: cellSize,
              height: cellSize,
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.green),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            width: cellSize,
            height: cellSize,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image,
                color: Colors.grey, size: 32),
          ),
        );
      } else if (item.localPath != null &&
          File(item.localPath!).existsSync()) {
        img = Image.file(
          File(item.localPath!),
          width: cellSize,
          height: cellSize,
          fit: BoxFit.cover,
          cacheHeight: 300,
        );
      } else {
        img = Container(
          width: cellSize,
          height: cellSize,
          color: Colors.grey[300],
          child:
              const Icon(Icons.image, color: Colors.grey, size: 32),
        );
      }

      Widget cell = ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: img,
      );

      if (showOverlay && extraCount > 0) {
        cell = Stack(children: [
          cell,
          Container(
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '+$extraCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ]);
      }

      return GestureDetector(
        onTap: () => _openGallery(items, index),
        child: cell,
      );
    }

    // Layout: 1 image = full width, 2 = side by side, 3+ = 2×2 grid
    if (displayCount == 1) {
      return GestureDetector(
        onTap: () => _openGallery(items, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: items[0].url != null
              ? Image.network(items[0].url!,
                  width: gridSize,
                  height: gridSize,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, progress) =>
                      progress == null
                          ? child
                          : Container(
                              width: gridSize,
                              height: gridSize,
                              color: Colors.grey[300],
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.green)),
                            ),
                  errorBuilder: (_, __, ___) => Container(
                      width: gridSize,
                      height: gridSize,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image,
                          color: Colors.grey, size: 48)),
                )
              : items[0].localPath != null
                  ? Image.file(File(items[0].localPath!),
                      width: gridSize,
                      height: gridSize,
                      fit: BoxFit.cover)
                  : Container(
                      width: gridSize,
                      height: gridSize,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image,
                          color: Colors.grey, size: 48)),
        ),
      );
    }

    if (displayCount == 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildCell(0),
          const SizedBox(width: gap),
          buildCell(1, showOverlay: extraCount > 0),
        ],
      );
    }

    // 3 or 4 cells → 2×2 grid
    return SizedBox(
      width: gridSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            buildCell(0),
            const SizedBox(width: gap),
            buildCell(1),
          ]),
          const SizedBox(height: gap),
          Row(mainAxisSize: MainAxisSize.min, children: [
            buildCell(2),
            const SizedBox(width: gap),
            buildCell(
              displayCount == 4 ? 3 : 2,
              showOverlay: extraCount > 0 || displayCount == 3,
            ),
          ]),
        ],
      ),
    );
  }

  void _openGallery(List<AttachmentItem> items, int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _GalleryView(items: items, initialIndex: initialIndex),
    ));
  }

  // ─── Single attachment (document or legacy single image) ────────────────────

  Widget _buildSingleAttachment(ChatMessage message) {
    if (message.fileType == 'image') {
      // Wrap in a 1-item list and reuse grid (handles local vs remote)
      final item = AttachmentItem(
        url: message.attachmentUrl,
        localPath: message.filePath,
        fileName: message.fileName,
        mimeType: message.attachmentType,
      );
      return _buildImageGrid([item], message.isMe, message.id);
    }

    // Document
    final name = message.fileName ?? message.text;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: message.isMe ? Colors.green[700] : Colors.grey[400],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.insert_drive_file,
            color: message.isMe ? Colors.white : Colors.black87, size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name,
            style: TextStyle(
              color: message.isMe ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
        ),
      ]),
    );
  }

  // ─── Message bubble ─────────────────────────────────────────────────────────

  Widget _buildMessage(ChatMessage message) {
    final isSelected = _selectedMessageId == message.id;
    final hasGrouped = message.hasGroupedAttachments;
    final showText = message.text.isNotEmpty &&
        message.fileType != 'image' &&
        message.fileType != 'document' &&
        !hasGrouped;

    // Determine if this is a pure image bubble (no text padding needed)
    final isImageBubble = hasGrouped
        ? message.isImageGroup
        : message.fileType == 'image';

    return GestureDetector(
      onLongPress: () => setState(() => _selectedMessageId = message.id),
      onTap: () => setState(() => _selectedMessageId = null),
      child: Container(
        color: isSelected
            ? Colors.grey.withOpacity(0.1)
            : Colors.transparent,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: message.isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!message.isMe) ...[
                CircleAvatar(
                  backgroundColor: widget.contact.avatarColor,
                  radius: 15,
                  child: Text(widget.contact.initials,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  // For image-only bubbles, use tighter padding
                  padding: isImageBubble
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: message.isMe
                        ? Colors.green
                        : const Color.fromARGB(255, 200, 199, 199),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Attachment area ──
                      if (hasGrouped) ...[
                        _buildImageGrid(message.groupedAttachments,
                            message.isMe, message.id),
                      ] else if (message.fileType != null) ...[
                        _buildSingleAttachment(message),
                      ],

                      if (hasGrouped || message.fileType != null)
                        const SizedBox(height: 4),

                      // ── Text ──
                      if (showText)
                        Padding(
                          padding: isImageBubble
                              ? const EdgeInsets.symmetric(horizontal: 8)
                              : EdgeInsets.zero,
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: message.isMe
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ),

                      // ── Time + read tick ──
                      Padding(
                        padding: isImageBubble
                            ? const EdgeInsets.only(
                                right: 8, left: 8, bottom: 4)
                            : EdgeInsets.zero,
                        child: Row(
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
                      ),
                    ],
                  ),
                ),
              ),
              // ── Delete button when selected ──
              if (isSelected) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _deleteMessage(message.id),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Date separator ─────────────────────────────────────────────────────────

  Widget _buildDateSeparator(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 236, 236, 226),
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

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      child: Scaffold(
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
          title: Row(children: [
            Stack(children: [
              CircleAvatar(
                backgroundColor: widget.contact.avatarColor,
                radius: 18,
                child: Text(widget.contact.initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
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
                      border:
                          Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.contact.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    widget.contact.isOnline
                        ? 'Online'
                        : 'Last seen recently',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _fetchMessagesFromApi(silent: false),
            ),
            IconButton(
                icon: const Icon(Icons.more_vert), onPressed: () {}),
          ],
        ),
        body: Column(children: [
          if (_isLoadingMessages)
            const LinearProgressIndicator(
              backgroundColor: Colors.grey,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
              color: Colors.green.shade50,
              child: const Row(children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.green),
                ),
                SizedBox(width: 10),
                Text('Uploading file(s)...',
                    style:
                        TextStyle(fontSize: 13, color: Colors.green)),
              ]),
            ),
          Expanded(
            child: Container(
              color: const Color.fromARGB(255, 245, 245, 230),
              child: _messages.isEmpty
                  ? const Center(
                      child: Text('No messages yet',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 16)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (ctx, index) {
                        final ri = _messages.length - 1 - index;
                        final msg = _messages[ri];
                        return Column(children: [
                          if (_shouldShowDateSeparator(ri))
                            _buildDateSeparator(msg.timestamp),
                          _buildMessage(msg),
                        ]);
                      },
                    ),
            ),
          ),
          // ── Input bar ──
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
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.grey),
                onPressed: _onCameraPressed,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.attach_file,
                          color: Colors.grey),
                      onPressed: _onAttachFilePressed,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _sendMessage(),
                  onTap: () {
                    Future.delayed(const Duration(milliseconds: 300),
                        () {
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
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Full-screen gallery viewer ────────────────────────────────────────────────

class _GalleryView extends StatefulWidget {
  final List<AttachmentItem> items;
  final int initialIndex;

  const _GalleryView({required this.items, required this.initialIndex});

  @override
  State<_GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<_GalleryView> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.items.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (ctx, i) {
          final item = widget.items[i];
          Widget img;
          if (item.url != null && item.url!.isNotEmpty) {
            img = Image.network(item.url!, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 80));
          } else if (item.localPath != null &&
              File(item.localPath!).existsSync()) {
            img = Image.file(File(item.localPath!),
                fit: BoxFit.contain);
          } else {
            img = const Icon(Icons.image, color: Colors.white, size: 80);
          }
          return InteractiveViewer(child: Center(child: img));
        },
      ),
    );
  }
}