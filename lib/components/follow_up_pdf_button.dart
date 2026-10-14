// ============================================================
// FILE: lib/components/follow_up_pdf_button.dart
//
// Builds a watermarked PDF of one follow-up and offers the same two ways out
// as ReservationPdfButtonBallys: the OS share sheet (WhatsApp and friends) and
// the app's own chat, to any mix of 1:1 conversations and groups.
//
// Only the AD001 admin may share any follow-up; everyone else sees the
// buttons on their own follow-ups only.
//
// USAGE in FollowUpViewScreen:
//   FollowUpPdfButton(item: item),
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ballys_reservation_app/components/forward_message_sheet.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/follow_up_item.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/follow_up_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/screens/media_preview_screen.dart';

class FollowUpPdfButton extends ConsumerStatefulWidget {
  final FollowUpItem item;

  const FollowUpPdfButton({super.key, required this.item});

  /// AD001 may share every follow-up; anyone else only the ones they saved.
  static bool canShare({
    required FollowUpItem item,
    required String? currentUser,
    required bool isAdmin,
  }) {
    if (isAdmin) return true;
    final me = currentUser?.trim().toLowerCase() ?? '';
    final owner = item.loginBy?.trim().toLowerCase() ?? '';
    return me.isNotEmpty && me == owner;
  }

  @override
  ConsumerState<FollowUpPdfButton> createState() => _FollowUpPdfButtonState();
}

class _FollowUpPdfButtonState extends ConsumerState<FollowUpPdfButton> {
  /// True while the picked chats are being uploaded to, so both buttons are
  /// held shut and the chat one shows progress.
  bool _isSendingToChat = false;

  /// True while the PDF is being built for the share sheet.
  bool _isSharing = false;

  FollowUpItem get _item => widget.item;

  String _fmt(DateTime dt) => DateFormat('dd MMM yyyy  hh:mm a').format(dt);

  /// The member's guest record (profile photo, last visit). The details
  /// screen's GuestDisplayCardById normally has it loaded already; fetch it
  /// only when the selected guest is someone else. Never fails the share.
  Future<Guest?> _loadGuest() async {
    bool isThisMember(Guest? g) =>
        g != null &&
        g.mid.trim().toLowerCase() == _item.memberId.trim().toLowerCase();

    var guest = ref.read(selectedGuestProvider);
    if (isThisMember(guest) && guest!.memberName.isNotEmpty) return guest;

    try {
      final notifier = ref.read(selectedGuestProvider.notifier);
      await notifier.setSelectedGuestWithId(_item.memberId);
      await notifier.getGuestImage(9022, _item.memberId);
      guest = ref.read(selectedGuestProvider);
    } catch (e) {
      debugPrint('Follow-up PDF guest load failed: $e');
    }
    return isThisMember(guest) ? guest : null;
  }

  static Uint8List? _decodeImage(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Same rules as GuestDisplayCardById: blank or the 1970 epoch means none.
  static String? _formatLastVisit(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    if (date.year == 1970 && date.month == 1 && date.day == 1) return null;
    return DateFormat('dd MMM yyyy').format(date);
  }

  // ── PDF builder ──────────────────────────────────────────────────────────
  Future<pw.Document> _buildPdf() async {
    // Fonts come from Google Fonts like the reservation PDF; offline, fall
    // back to the built-in Helvetica rather than failing the share.
    pw.ThemeData theme;
    try {
      theme = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.nunitoRegular(),
        bold: await PdfGoogleFonts.nunitoBold(),
      );
    } catch (e) {
      debugPrint('Follow-up PDF font load failed: $e');
      theme = pw.ThemeData.base();
    }

    final sharedBy = ref.read(currentUserNameProvider).valueOrNull ?? '';
    final generatedAt = _fmt(DateTime.now());
    final photo = _item.photoBytes;
    final guest = await _loadGuest();
    final profilePic = _decodeImage(guest?.memImage2);
    final lastVisit = _formatLastVisit(guest?.lastVisitDate);

    final labelStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 11,
    );
    const valueStyle = pw.TextStyle(fontSize: 11);

    pw.Widget row(String label, String? value, {PdfColor? color}) {
      final text = (value == null || value.trim().isEmpty) ? '-' : value;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 130, child: pw.Text(label, style: labelStyle)),
            pw.Expanded(
              child: pw.Text(
                text,
                style: color == null
                    ? valueStyle
                    : valueStyle.copyWith(
                        color: color,
                        fontWeight: pw.FontWeight.bold,
                      ),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget section(String title, List<pw.Widget> children) {
      return pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 14),
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            ...children,
          ],
        ),
      );
    }

    final responseColor = _item.isPositive
        ? PdfColors.green700
        : _item.isNegative
        ? PdfColors.red
        : null;

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: theme,
          // Background, so the watermark repeats on every page and sits
          // behind the content.
          buildBackground: (context) => _buildWatermark(sharedBy, generatedAt),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'System generated · Shared by ${sharedBy.isEmpty ? '-' : sharedBy}'
            ' · $generatedAt · Page ${context.pageNumber}/${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'FOLLOW-UP DETAILS',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 18),
          section('MEMBER', [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      row('Member ID:', _item.memberId),
                      row('Member Name:', _item.memberName),
                      row('Last Visit Date:', lastVisit),
                      row('Date Range:', _item.dateRange),
                      row('Buy-in Range:', _item.buyInRange),
                      row('Followed by:', _item.loginBy),
                      row(
                        'Follow-up Date:',
                        _item.createdDate == null
                            ? null
                            : _fmt(_item.createdDate!),
                      ),
                    ],
                  ),
                ),
                if (profilePic != null) ...[
                  pw.SizedBox(width: 12),
                  pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(
                      pw.MemoryImage(profilePic),
                      width: 100,
                      height: 120,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ]),
          section('FOLLOW-UP', [
            row('Description:', _item.description),
            row('Contact Status:', _item.contactStatus),
            if (_item.contactStatus == 'Contacted') ...[
              row('Response:', _item.responseType, color: responseColor),
              row('Customer Response:', _item.customerResponse),
              if (_item.remarks != null && _item.remarks!.isNotEmpty)
                row('Remarks:', _item.remarks),
              if (_item.isPositive) ...[
                row(
                  'Checklist:',
                  _item.checklistItems.isEmpty
                      ? null
                      : _item.checklistItems.map((c) => '• $c').join('\n'),
                ),
                row('Status:', _item.positiveStatus),
              ],
            ],
          ]),
          if (photo != null)
            section('PHOTO', [
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(photo),
                  height: 260,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ]),
        ],
      ),
    );

    return pdf;
  }

  /// The sharer's name and the time, tiled diagonally across the whole page.
  pw.Widget _buildWatermark(String userName, String generatedAt) {
    final text = '${userName.isEmpty ? 'Ballys' : userName}\n$generatedAt';

    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Opacity(
        opacity: 0.15,
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: List.generate(
            9,
            (r) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: List.generate(
                3,
                (c) => pw.Transform.rotate(
                  angle: 0.5,
                  child: pw.Text(
                    text,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Member ids and names can carry characters that don't belong in a
  /// filename, so keep only what is safe on disk.
  String get _pdfFileName {
    final safe = '${_item.memberId}_${_item.memberName}'
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return 'FollowUp_${safe.isEmpty ? 'details' : safe}.pdf';
  }

  // ── Share PDF via WhatsApp ────────────────────────────────────────────────
  Future<void> _sharePdfToWhatsApp() async {
    if (_isSharing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSharing = true);
    try {
      final doc = await _buildPdf();
      final bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: _pdfFileName);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to share PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // ── Send PDF into the in-app chat ─────────────────────────────────────────
  //
  // Same flow as the reservation PDF: the upload endpoint takes file paths, so
  // the document goes to the temp directory first; a first-time recipient has
  // a chat opened for them before the upload.
  Future<void> _sendPdfToChat() async {
    if (_isSendingToChat) return;

    final messenger = ScaffoldMessenger.of(context);
    final fontSettings = ref.read(fontSettingsProvider);

    final targets = await showForwardMessageSheet(
      context: context,
      fontSettings: fontSettings,
      messageCount: 1,
      title: 'Send follow-up PDF',
      icon: Icons.picture_as_pdf,
    );
    if (targets == null || targets.isEmpty || !mounted) return;

    // Build the PDF first so the preview can show the real file.
    setState(() => _isSendingToChat = true);
    final File file;
    try {
      final doc = await _buildPdf();
      final bytes = await doc.save();
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/$_pdfFileName');
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingToChat = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to prepare PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    // Same preview + caption screen the chat uses for documents. Null means
    // the user closed it, so nothing is sent.
    final preview = await Navigator.of(context).push<MediaPreviewResult>(
      MaterialPageRoute(
        builder: (_) => MediaPreviewScreen(
          filePaths: [file.path],
          recipientName: targets.names.join(', '),
        ),
      ),
    );
    if (!mounted) return;
    if (preview == null || preview.filePaths.isEmpty) {
      setState(() => _isSendingToChat = false);
      return;
    }
    final caption = preview.caption;

    final sent = <String>[];
    final failed = <String>[];
    String? firstError;

    try {
      // Groups first, matching the order the picker reports names in.
      for (var i = 0; i < targets.chatIds.length; i++) {
        final name = i < targets.names.length ? targets.names[i] : 'Group';
        final error = await _uploadPdfTo(
          targets.chatIds[i],
          file.path,
          caption,
        );
        (error == null ? sent : failed).add(name);
        if (error != null) firstError ??= error;
      }

      for (final contact in targets.contacts) {
        var chatId = contact.chatUuid;

        if (chatId.isEmpty) {
          final created = await FirebaseApiService.createChatDetailed(
            contact.userUuid,
            userAppType: contact.appType,
          );
          chatId = (created['chatId'] as String?) ?? '';
          if (chatId.isEmpty) {
            failed.add(contact.name);
            firstError ??= created['error']?.toString();
            continue;
          }
        }

        final error = await _uploadPdfTo(chatId, file.path, caption);
        (error == null ? sent : failed).add(contact.name);
        if (error != null) firstError ??= error;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingToChat = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to send PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isSendingToChat = false);

    final reason = firstError == null ? '' : ': $firstError';
    final message = failed.isEmpty
        ? 'Follow-up PDF sent to ${sent.join(', ')}'
        : sent.isEmpty
        ? 'Could not send to ${failed.join(', ')}$reason'
        : 'Sent to ${sent.join(', ')} · failed for '
              '${failed.join(', ')}$reason';

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: failed.isEmpty
            ? Colors.green
            : (sent.isEmpty ? Colors.red : Colors.orange),
      ),
    );
  }

  /// Returns null when the upload landed, or why it did not.
  Future<String?> _uploadPdfTo(
    String chatId,
    String filePath,
    String? caption,
  ) async {
    try {
      final result = await FirebaseApiService.uploadFiles(
        chatId: chatId,
        filePaths: [filePath],
        caption: caption,
      );
      if (result['success'] == true) return null;
      return FirebaseApiService.errorTextFrom(result);
    } catch (e) {
      return e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserNameProvider).valueOrNull;
    final isAdmin = ref.watch(isAdminSalesCodeProvider).valueOrNull ?? false;
    if (!FollowUpPdfButton.canShare(
      item: _item,
      currentUser: currentUser,
      isAdmin: isAdmin,
    )) {
      return const SizedBox.shrink();
    }

    final busy = _isSharing || _isSendingToChat;

    // One Share button; the ways to share are picked from a popup.
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.share, size: 20),
        label: Text(
          _isSharing
              ? 'PREPARING...'
              : _isSendingToChat
              ? 'SENDING...'
              : 'SHARE',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0C3B79),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(
            0xFF0C3B79,
          ).withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        onPressed: busy ? null : _showShareOptions,
      ),
    );
  }

  /// The popup behind the Share button: WhatsApp or the in-app chat.
  Future<void> _showShareOptions() async {
    final choice = await showModalBottomSheet<VoidCallback>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share follow-up',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _shareOption(
                    // label: 'WhatsApp',
                    button: _pdfButton(
                      color: const Color(0xFF25D366),
                      icon: FontAwesomeIcons.whatsapp,
                      tooltip: 'Share follow-up via WhatsApp',
                      busy: false,
                      onPressed: () =>
                          Navigator.pop(dialogContext, _sharePdfToWhatsApp),
                    ),
                  ),
                  _shareOption(
                    // label: 'Chat',
                    button: _pdfButton(
                      color: const Color.fromARGB(255, 221, 117, 5),
                      iconAsset: 'assets/images/logo.png',
                      tooltip: 'Send follow-up via chat',
                      busy: false,
                      onPressed: () =>
                          Navigator.pop(dialogContext, _sendPdfToChat),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null && mounted) choice();
  }

  Widget _shareOption({required Widget button}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 8),
        // Text(
        //   label,
        //   style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        // ),
      ],
    );
  }

  Widget _pdfButton({
    required Color color,
    IconData? icon,
    String? iconAsset,
    required String tooltip,
    required bool busy,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: CircleBorder(side: BorderSide(color: color, width: 2)),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Padding(
              // The logo has its own margin baked in; give it more of the
              // circle so it reads at the same size as the WhatsApp glyph.
              padding: EdgeInsets.all(icon != null ? 10 : 2),
              child: busy
                  ? CircularProgressIndicator(strokeWidth: 2.5, color: color)
                  : Opacity(
                      opacity: onPressed == null ? 0.4 : 1,
                      child: icon != null
                          ? FittedBox(child: FaIcon(icon, color: color))
                          : Image.asset(iconAsset!, fit: BoxFit.contain),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
