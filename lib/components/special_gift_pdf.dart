import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class DirectWhatsAppPdfService {
  // Share directly to WhatsApp with PDF attachment
  static Future<void> shareDirectlyToWhatsApp({
    required String memberName,
    required String memberId,
    required String fromDateTime,
    required String toDateTime,
    required String arrivalDate,
    required String departureDate,
    required String giftFor,
    required String chipType,
    required String amount,
    required String remarks,
    required String userName,
    required Map<String, dynamic> guestData,
    required String returnSerial,
    Rect? sharePositionOrigin, // ← NEW: required for iOS share sheet anchor
  }) async {
    try {
      final pdf = await _generateGiftRequestPdf(
        memberName: memberName,
        memberId: memberId,
        fromDateTime: fromDateTime,
        toDateTime: toDateTime,
        arrivalDate: arrivalDate,
        departureDate: departureDate,
        giftFor: giftFor,
        chipType: chipType,
        amount: amount,
        remarks: remarks,
        userName: userName,
        guestData: guestData,
        returnSerial: returnSerial,
      );

      final output = await getTemporaryDirectory();
      final fileName =
          'GiftRequest_${memberName.replaceAll(' ', '_')}_${returnSerial.toString()}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      final message =
          'Special Gift Request for $memberName\n\n'
          'Member ID: $memberId\n'
          'Amount: $amount\n'
          'Gift Type: $giftFor\n'
          'Chip Type: $chipType\n\n'
          'Request Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}\n'
          'Request By: $userName\n'
          'Return Serial: $returnSerial\n\n'
          'Please find the attached gift request document.';

      if (Platform.isIOS) {
        // ← FIX: provide a valid sharePositionOrigin for iOS popover anchor
        final rect = sharePositionOrigin ??
            const Rect.fromLTWH(0, 100, 300, 300);

        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          text: message,
          subject: 'Gift Request - $memberName',
          sharePositionOrigin: rect,
        );
      } else {
        await _shareOnAndroid(file, message, memberName);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> _shareOnAndroid(
    File pdfFile,
    String message,
    String memberName,
  ) async {
    await Share.share(message, subject: 'Gift Request - $memberName');
    await Future.delayed(const Duration(milliseconds: 500));
    await Share.shareXFiles([
      XFile(pdfFile.path, mimeType: 'application/pdf'),
    ], subject: 'Gift Request - $memberName PDF');
  }

  static Future<String> savePdfAndProvideInstructions({
    required String memberName,
    required String memberId,
    required String fromDateTime,
    required String toDateTime,
    required String arrivalDate,
    required String departureDate,
    required String giftFor,
    required String chipType,
    required String amount,
    required String remarks,
    required String userName,
    required Map<String, dynamic> guestData,
    required String returnSerial,
  }) async {
    try {
      final pdf = await _generateGiftRequestPdf(
        memberName: memberName,
        memberId: memberId,
        fromDateTime: fromDateTime,
        toDateTime: toDateTime,
        arrivalDate: arrivalDate,
        departureDate: departureDate,
        giftFor: giftFor,
        chipType: chipType,
        amount: amount,
        remarks: remarks,
        userName: userName,
        guestData: guestData,
        returnSerial: returnSerial,
      );

      Directory saveDirectory;
      if (Platform.isAndroid) {
        saveDirectory = Directory('/storage/emulated/0/Download');
        if (!await saveDirectory.exists()) {
          saveDirectory =
              await getExternalStorageDirectory() ??
              await getTemporaryDirectory();
        }
      } else {
        saveDirectory = await getApplicationDocumentsDirectory();
      }

      final fileName =
          'GiftRequest_${memberName.replaceAll(' ', '_')}_${returnSerial.toString()}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${saveDirectory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      return fileName;
    } catch (e) {
      rethrow;
    }
  }

  static Future<pw.Document> _generateGiftRequestPdf({
    required String memberName,
    required String memberId,
    required String fromDateTime,
    required String toDateTime,
    required String arrivalDate,
    required String departureDate,
    required String giftFor,
    required String chipType,
    required String amount,
    required String remarks,
    required String userName,
    required Map<String, dynamic> guestData,
    required String returnSerial,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Stack(
            children: [
              _buildWatermark(userName),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'SPECIAL GIFT REQUEST',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 20),
                      ],
                    ),
                  ),
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(5),
                      ),
                    ),
                    padding: const pw.EdgeInsets.all(16),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'REQUEST DETAILS',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        _buildInfoRow('Member Name:', memberName),
                        _buildInfoRow('Member ID:', memberId),
                        _buildInfoRow('From Date & Time:', fromDateTime),
                        _buildInfoRow('To Date & Time:', toDateTime),
                        _buildInfoRow('Arrival Date:', arrivalDate),
                        _buildInfoRow('Departure Date:', departureDate),
                        _buildInfoRow('Gift For:', giftFor, highlight: true),
                        _buildInfoRow('Chip Type:', chipType, highlight: true),
                        _buildInfoRow('Amount:', amount, highlight: true),
                        if (remarks.isNotEmpty)
                          _buildInfoRow('Remarks:', remarks),
                        _buildInfoRow('Requested by:', userName),
                        _buildInfoRow(
                          'Request Date:',
                          DateTime.now().toString().split('.')[0],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  _buildGuestDataSection(guestData),
                  pw.SizedBox(height: 10),

                  pw.Spacer(),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'This is a system generated document.',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Generated on: ${DateTime.now().toString().split('.')[0]}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildWatermark(String userName) {
    final now = DateTime.now();
    final lastSeen = DateFormat('dd MMM yyyy, hh:mm a').format(now);
    final watermarkText = '$userName\n$lastSeen';

    return pw.Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: pw.Transform.rotate(
        angle: -0.7,
        child: pw.Opacity(
          opacity: 0.3,
          child: pw.GridView(
            crossAxisCount: 4,
            mainAxisSpacing: 30,
            crossAxisSpacing: 20,
            children: List.generate(
              30,
              (index) => pw.Center(
                child: pw.Text(
                  watermarkText,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildInfoRow(
    String label,
    String value, {
    bool highlight = false,
  }) {
    final style = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: highlight ? PdfColors.red : PdfColors.black,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 140, child: pw.Text(label, style: style)),
          pw.Expanded(child: pw.Text(value, style: style)),
        ],
      ),
    );
  }

  static String _formatNumericValue(dynamic value) {
    if (value == null) return 'N/A';
    double numValue;
    if (value is String) {
      numValue = double.tryParse(value) ?? 0.0;
    } else if (value is num) {
      numValue = value.toDouble();
    } else {
      return 'N/A';
    }
    if (numValue.abs() < 0.01) return 'N/A';
    final formatter = NumberFormat('#,###', 'en_US');
    return formatter.format(numValue.round());
  }

  static pw.Widget _buildGuestDataSection(Map<String, dynamic> guestData) {
    final highlightedFields = {
      'Actual Drop (Est)',
      'Result (Est)',
      'Coupons (Est)',
      'Points (Est)',
      'Avg Bet (Est)',
    };

    final fields = {
      'Drop (Est)': _formatNumericValue(guestData['guestDrop']),
      'Cash Out (Est)': _formatNumericValue(guestData['tmpCashout']),
      'Result (Est)': _formatNumericValue(guestData['res']),
      'Actual Drop (Est)': _formatNumericValue(guestData['actD']),
      'Coupons (Est)': _formatNumericValue(guestData['guestCoupon']),
      'Commission Paid (Est)': _formatNumericValue(guestData['tmpCommpaid']),
      'Points (Est)': _formatNumericValue(guestData['tmpPoint']),
      'Flush Coupon (Est)': _formatNumericValue(guestData['flushCoupon']),
      'Flush Actual Drop (Est)': _formatNumericValue(guestData['flushActDrop']),
      'Avg Bet (Est)': _formatNumericValue(guestData['tmpAvgBet']),
    };

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              'Field',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              'Value',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    ];

    if (guestData.isEmpty) {
      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'No guest data available',
                style: pw.TextStyle(
                  fontStyle: pw.FontStyle.italic,
                  fontSize: 11,
                ),
              ),
            ),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
          ],
        ),
      );
    } else {
      fields.forEach((label, value) {
        final isHighlighted = highlightedFields.contains(label);
        rows.add(
          pw.TableRow(
            decoration: isHighlighted
                ? const pw.BoxDecoration(color: PdfColors.yellow100)
                : null,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: isHighlighted
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    color: isHighlighted ? PdfColors.red800 : PdfColors.black,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  value,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: isHighlighted ? PdfColors.red800 : PdfColors.black,
                  ),
                ),
              ),
            ],
          ),
        );
      });
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'GUEST GIFT DATA',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: rows,
          ),
        ],
      ),
    );
  }
}