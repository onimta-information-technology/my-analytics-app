import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class DirectWhatsAppPdfService {
  // This is the BEST approach - uses Share.shareXFiles with WhatsApp preference
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
  }) async {
    try {
      // Generate PDF
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

      // Save PDF to temporary directory
      final output = await getTemporaryDirectory();
      final fileName =
          'GiftRequest_${memberName.replaceAll(' ', '_')}_${returnSerial.toString()}_${DateTime.now()}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Create the share message
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

      // Share with system dialog - PDF will be attached automatically
      if (Platform.isIOS) {
        // iOS: Share both text and file together (works well on iOS)
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          text: message,
          subject: 'Gift Request - $memberName',
        );
      } else {
        // Android: Two-step process for better compatibility
        await _shareOnAndroid(file, message, memberName);
      }
    } catch (e) {
      print('Error sharing PDF: $e');
      rethrow;
    }
  }
  //   static Future<void> _shareOnAndroidAlternative(File pdfFile, String message, String memberName) async {
  //   // Create a combined approach: share file with filename containing key info
  //   final enhancedFileName = 'GiftRequest_${memberName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
  //   final enhancedFile = File('${pdfFile.parent.path}/$enhancedFileName');
  //   await pdfFile.copy(enhancedFile.path);

  //   await Share.shareXFiles(
  //     [XFile(enhancedFile.path, mimeType: 'application/pdf')],
  //     text: message, // Some Android apps might still show this
  //     subject: 'Gift Request - $memberName',
  //   );
  // }

  static Future<void> _shareOnAndroid(
    File pdfFile,
    String message,
    String memberName,
  ) async {
    // Option 1: Share text first, then file
    // First share the text message
    await Share.share(message, subject: 'Gift Request - $memberName');

    // Small delay to let user complete first share if needed
    await Future.delayed(const Duration(milliseconds: 500));

    // Then share the PDF
    await Share.shareXFiles([
      XFile(pdfFile.path, mimeType: 'application/pdf'),
    ], subject: 'Gift Request - $memberName PDF');
  }

  // Alternative: Save to a more accessible location and provide clear instructions
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
      // Generate PDF
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

      // Save to Downloads directory (Android) or Documents (iOS)
      Directory saveDirectory;
      if (Platform.isAndroid) {
        // Try to save to Downloads folder
        saveDirectory = Directory('/storage/emulated/0/Download');
        if (!await saveDirectory.exists()) {
          // Fallback to external storage directory
          saveDirectory =
              await getExternalStorageDirectory() ??
              await getTemporaryDirectory();
        }
      } else {
        // iOS - save to Documents directory
        saveDirectory = await getApplicationDocumentsDirectory();
      }

      final fileName =
          'GiftRequest_${memberName.replaceAll(' ', '_')}_${returnSerial.toString()}_${DateTime.now()}.pdf';
      final file = File('${saveDirectory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      print(fileName);
      return fileName;
      // Return just the filename for user reference
    } catch (e) {
      print('Error saving PDF: $e');
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
              // Watermark layer - positioned behind content
              _buildWatermark(userName),

              // Content layer
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'SPECIAL GIFT REQUEST - Bally\'s Casino',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // Request Details Section
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
                        _buildInfoRow('Gift For:', giftFor,highlight: true),
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

                  // Guest Data Section - only show if data exists and has meaningful values
                  //  if (guestData.isNotEmpty &&
                  //   _hasGuestDataValues(guestData)) ...[
                  if (guestData.isNotEmpty) ...[
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
                            'GUEST GIFT DATA',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 10),

                          pw.Table(
                            border: pw.TableBorder.all(
                              color: PdfColors.grey400,
                            ),
                            children: [
                              pw.TableRow(
                                decoration: const pw.BoxDecoration(
                                  color: PdfColors.grey200,
                                ),
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(8),
                                    child: pw.Text(
                                      'Field',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(8),
                                    child: pw.Text(
                                      'Value',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              ..._buildGuestDataRows(guestData),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),
                  ],

                  pw.Spacer(),

                  // Footer
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

  // Build watermark that covers the full page
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

  static pw.Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
      final style = pw.TextStyle(
    fontWeight: pw.FontWeight.bold,
    color: highlight ? PdfColors.red : PdfColors.black,
  );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: style),
            ),
    
          pw.Expanded(child: pw.Text(value,style: style)),
        ],
      ),
    );
  }
  static String _formatNumericValue(dynamic value) {
  if (value == null) return 'N/A';
  
  // Convert to double if it's not already
  double numValue;
  if (value is String) {
    numValue = double.tryParse(value) ?? 0.0;
  } else if (value is num) {
    numValue = value.toDouble();
  } else {
    return 'N/A';
  }
  
  // If the value is 0 or very close to 0, return 'N/A'
  if (numValue.abs() < 0.01) return 'N/A';
  
  // Create formatter for thousands separator without decimal places
  final formatter = NumberFormat('#,###', 'en_US');
  return formatter.format(numValue.round());
}


  static List<pw.TableRow> _buildGuestDataRows(Map<String, dynamic> guestData) {
    final rows = <pw.TableRow>[];
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

    for (final entry in fields.entries) {
      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(entry.key),
              
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(entry.value, textAlign: pw.TextAlign.right),
            ),
          ],
        ),
      );
    }

    return rows;
  }

  // Helper function to check if guest data has meaningful values
  // static bool _hasGuestDataValues(Map<String, dynamic> guestData) {
  //   // Check if any of the guest data fields have non-zero, non-null values
  //   final fieldsToCheck = [
  //     'guestDrop',
  //     'tmpCashout',
  //     'res',
  //     'actD',
  //     'guestCoupon',
  //     'tmpCommpaid',
  //     'tmpPoint',
  //     'flushCoupon',
  //     'flushActDrop',
  //     'tmpAvgBet',
  //   ];

  //   for (String field in fieldsToCheck) {
  //     final value = guestData[field];
  //     if (value != null &&
  //         value != 0 &&
  //         value.toString() != '0' &&
  //         value.toString().trim().isNotEmpty) {
  //       return true;
  //     }
  //   }
  //   return false;
  // }
}
