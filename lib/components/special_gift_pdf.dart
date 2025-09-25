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
          'GiftRequest_${memberId}_${returnSerial.toString()}_${DateTime.now()}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Create the share message
      final message =
          'Special Gift Request for $memberName\n\n'
          'Member ID: $memberId\n'
          'Amount: $amount\n'
          'Gift Type: $giftFor\n'
          'Chip Type: $chipType\n\n'
          'Please find the attached gift request document.';

      // Share with system dialog - PDF will be attached automatically
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: message,
        subject: 'Gift Request - $memberName',
        // Note: We can't force WhatsApp specifically, but it will appear in the share dialog
      );

      // The result will tell us if sharing was successful
      if (result.status == ShareResultStatus.success) {
        print('PDF shared successfully');
      }
    } catch (e) {
      print('Error sharing PDF: $e');
      rethrow;
    }
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
          'GiftRequest_${memberId}_${returnSerial.toString()}_${DateTime.now()}.pdf';
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
                        _buildInfoRow('Gift For:', giftFor),
                        _buildInfoRow('Chip Type:', chipType),
                        _buildInfoRow('Amount:', amount),
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
                  if (guestData.isNotEmpty &&
                      _hasGuestDataValues(guestData)) ...[
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

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  static List<pw.TableRow> _buildGuestDataRows(Map<String, dynamic> guestData) {
    final rows = <pw.TableRow>[];

    final fields = {
      'Drop (Est)': guestData['guestDrop']?.toString() ?? 'N/A',
      'Cash Out (Est)': guestData['tmpCashout']?.toString() ?? 'N/A',
      'Result (Est)': guestData['res']?.toString() ?? 'N/A',
      'Actual Drop (Est)': guestData['actD']?.toString() ?? 'N/A',
      'Coupons (Est)': guestData['guestCoupon']?.toString() ?? 'N/A',
      'Commission Paid (Est)': guestData['tmpCommpaid']?.toString() ?? 'N/A',
      'Points (Est)': guestData['tmpPoint']?.toString() ?? 'N/A',
      'Flush Coupon (Est)': guestData['flushCoupon']?.toString() ?? 'N/A',
      'Flush Actual Drop (Est)': guestData['flushActDrop']?.toString() ?? 'N/A',
      'Avg Bet (Est)': guestData['tmpAvgBet']?.toString() ?? 'N/A',
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
  static bool _hasGuestDataValues(Map<String, dynamic> guestData) {
    // Check if any of the guest data fields have non-zero, non-null values
    final fieldsToCheck = [
      'guestDrop',
      'tmpCashout',
      'res',
      'actD',
      'guestCoupon',
      'tmpCommpaid',
      'tmpPoint',
      'flushCoupon',
      'flushActDrop',
      'tmpAvgBet',
    ];

    for (String field in fieldsToCheck) {
      final value = guestData[field];
      if (value != null &&
          value != 0 &&
          value.toString() != '0' &&
          value.toString().trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }
}
