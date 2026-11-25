
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptPreviewScreen extends StatelessWidget {
  final String transactionNumber;
  final String date;
  final String type;
  final String productName;
  final String sku;
  final String quantity;
  final String status;

  const ReceiptPreviewScreen({
    super.key,
    required this.transactionNumber,
    required this.date,
    required this.type,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.status,
  });

  bool get isInbound => type == 'Stok Masuk';

  // ==========================================
  // GENERATE PDF
  // ==========================================

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          180 * PdfPageFormat.mm,
          marginAll: 5 * PdfPageFormat.mm,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 30,
                height: 30,
                decoration: pw.BoxDecoration(
                  color: PdfColors.black,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'S',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 5),

              pw.Text(
                'STOCK.CO',
                style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 3),

              pw.Text(
                'SMART WAREHOUSE & INVENTORY',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),

              pw.SizedBox(height: 15),

              _pdfDivider(),

              pw.SizedBox(height: 12),

              pw.Text(
                type.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: isInbound
                      ? PdfColors.green700
                      : PdfColors.red,
                ),
              ),

              pw.SizedBox(height: 6),

              pw.Text(
                transactionNumber,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 4),

              pw.Text(
                date,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),

              pw.SizedBox(height: 13),

              _pdfDivider(),

              pw.SizedBox(height: 12),

              _pdfRow('Barang', productName),
              _pdfRow('SKU', sku),
              _pdfRow('Jumlah', quantity),
              _pdfRow('Status', status),

              pw.SizedBox(height: 10),

              _pdfDivider(),

              pw.SizedBox(height: 12),

              pw.Text(
                'Terima kasih telah menggunakan Stock.co.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 8,
                ),
              ),

              pw.SizedBox(height: 5),

              pw.Text(
                'Simpan struk ini sebagai bukti transaksi gudang.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),

              pw.SizedBox(height: 15),

              pw.Text(
                '*** STOCK.CO ***',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================
  // PDF DIVIDER
  // ==========================================

  pw.Widget _pdfDivider() {
    return pw.Container(
      width: double.infinity,
      child: pw.Divider(
        color: PdfColors.grey500,
        thickness: 0.7,
      ),
    );
  }

  // ==========================================
  // PDF ROW
  // ==========================================

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 48,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
          ),

          pw.Text(
            ': ',
            style: const pw.TextStyle(
              fontSize: 8,
            ),
          ),

          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PRINT RECEIPT
  // ==========================================

  Future<void> _printReceipt(BuildContext context) async {
    try {
      final pdfBytes = await _generatePdf();

      if (!context.mounted) return;

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Struk_$transactionNumber.pdf',
      );
    } catch (e) {
      if (!context.mounted) return;

      _showMessage(
        context,
        'Gagal membuka cetak struk: $e',
      );
    }
  }

  // ==========================================
  // SAVE PDF
  // ==========================================

  Future<void> _savePdf(BuildContext context) async {
    try {
      final pdfBytes = await _generatePdf();

      if (!context.mounted) return;

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Struk_$transactionNumber.pdf',
      );
    } catch (e) {
      if (!context.mounted) return;

      _showMessage(
        context,
        'Gagal membuat PDF: $e',
      );
    }
  }

  // ==========================================
  // SHOW MESSAGE
  // ==========================================

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ==========================================
  // BUILD SCREEN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF202124),
          ),
          onPressed: () => Navigator.pop(context),
        ),

        title: const Text(
          'Pratinjau Struk',
          style: TextStyle(
            color: Color(0xFF202124),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),

        centerTitle: false,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            14,
            14,
            14,
            24,
          ),

          child: Column(
            children: [
              // TRANSACTION SUCCESS

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EF),
                  borderRadius: BorderRadius.circular(13),
                ),

                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,

                      decoration: const BoxDecoration(
                        color: Color(0xFF20B968),
                        shape: BoxShape.circle,
                      ),

                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),

                    const SizedBox(width: 11),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaksi Berhasil',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF168A4D),
                            ),
                          ),

                          SizedBox(height: 3),

                          Text(
                            'Struk transaksi berhasil dibuat.',
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF5F7568),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // RECEIPT PREVIEW

              _receiptPaper(),

              const SizedBox(height: 16),

              // PRINT BUTTON

              SizedBox(
                width: double.infinity,
                height: 45,

                child: ElevatedButton.icon(
                  onPressed: () => _printReceipt(context),

                  icon: const Icon(
                    Icons.print_outlined,
                    size: 19,
                  ),

                  label: const Text(
                    'Cetak Struk',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF587B55),
                    foregroundColor: Colors.white,
                    elevation: 0,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 9),

              // SAVE PDF BUTTON

              SizedBox(
                width: double.infinity,
                height: 45,

                child: OutlinedButton.icon(
                  onPressed: () => _savePdf(context),

                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 19,
                  ),

                  label: const Text(
                    'Simpan PDF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF587B55),

                    side: const BorderSide(
                      color: Color(0xFFD8E2D6),
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 9),

              // BACK BUTTON

              SizedBox(
                width: double.infinity,
                height: 45,

                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),

                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF587B55),

                    side: const BorderSide(
                      color: Color(0xFFD8E2D6),
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),

                  child: const Text(
                    'Kembali ke Riwayat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // RECEIPT PAPER
  // ==========================================

  Widget _receiptPaper() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(
        18,
        20,
        18,
        22,
      ),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,

                decoration: BoxDecoration(
                  color: const Color(0xFF101914),
                  borderRadius: BorderRadius.circular(4),
                ),

                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),

              const SizedBox(width: 7),

              const Text(
                'stock.co',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF101914),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          const Text(
            'SMART WAREHOUSE & INVENTORY',
            style: TextStyle(
              fontSize: 7,
              letterSpacing: 0.8,
              color: Color(0xFF8B93A1),
            ),
          ),

          const SizedBox(height: 18),

          const Divider(height: 1),

          const SizedBox(height: 14),

          Text(
            type.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,

              color: isInbound
                  ? const Color(0xFF18A96B)
                  : const Color(0xFFFF5964),
            ),
          ),

          const SizedBox(height: 7),

          Text(
            transactionNumber,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF202124),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            date,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF8B93A1),
            ),
          ),

          const SizedBox(height: 17),

          const Divider(height: 1),

          const SizedBox(height: 14),

          _row('Barang', productName),
          _row('SKU', sku),
          _row('Jumlah', quantity),
          _row('Status', status),

          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),

            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(8),
            ),

            child: const Text(
              'Terima kasih. Simpan struk ini sebagai bukti transaksi gudang.',
              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 8,
                height: 1.4,
                color: Color(0xFF777F89),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // RECEIPT ROW
  // ==========================================

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,

            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF8B93A1),
              ),
            ),
          ),

          const Text(
            ':',
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFF8B93A1),
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,

              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF30343B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
