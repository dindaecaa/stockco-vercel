
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_data.dart';

import '../home/home_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import '../inventory/add_sku_screen.dart';

import 'scanner_camera_screen.dart';
import 'scan_result_screen.dart';

class ScannerScreen extends StatelessWidget {
  final UserData? user;

  const ScannerScreen({
    super.key,
    this.user,
  });

  static const Color _green = Color(0xFF5E7C5B);
  static const Color _darkGreen = Color(0xFF587354);
  static const Color _background = Color(0xFFF5F5F5);

  static const String _baseUrl = 'http://localhost:3001';

  // =========================================================
  // AMBIL TOKEN LOGIN
  // =========================================================

  Future<String?> _getToken() async {
    // Prioritaskan token dari objek UserData.
    final userToken = user?.token;

    if (userToken != null && userToken.trim().isNotEmpty) {
      return userToken.trim();
    }

    // Jika token tidak ada, ambil dari SharedPreferences.
    final prefs = await SharedPreferences.getInstance();

    final savedToken = prefs.getString('token');

    if (savedToken != null && savedToken.trim().isNotEmpty) {
      return savedToken.trim();
    }

    return null;
  }

  // =========================================================
  // INPUT BARCODE MANUAL
  // =========================================================

  Future<void> _showManualEntry(BuildContext context) async {
    final controller = TextEditingController();

    final barcode = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Input Barcode / SKU',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Masukkan SKU barang',
              hintText: 'Contoh: SKU001',
              prefixIcon: const Icon(Icons.qr_code),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onSubmitted: (value) {
              Navigator.pop(
                dialogContext,
                value.trim(),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Batal',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cari Barang'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!context.mounted ||
        barcode == null ||
        barcode.trim().isEmpty) {
      return;
    }

    await _lookupProduct(
      context,
      barcode.trim(),
    );
  }

  // =========================================================
  // CARI SKU KE DATABASE
  // =========================================================

  Future<void> _lookupProduct(
    BuildContext context,
    String barcode,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sedang mencari barang...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Ambil token autentikasi.
      final token = await _getToken();

      if (!context.mounted) return;

      // Header request API.
      final headers = <String, String>{
        'Accept': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Request data barang dari backend.
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/products'),
            headers: headers,
          )
          .timeout(
            const Duration(seconds: 15),
          );

      if (!context.mounted) return;

      if (response.statusCode == 401) {
        throw Exception(
          'Sesi login telah berakhir. Silakan login kembali.',
        );
      }

      if (response.statusCode == 403) {
        throw Exception(
          'Kamu tidak memiliki akses untuk melihat data barang.',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Gagal mengambil data barang. '
          'Kode: ${response.statusCode}',
        );
      }

      // Decode respons JSON.
      final body = jsonDecode(response.body);

      if (body is! Map ||
          body['success'] != true ||
          body['data'] is! List) {
        throw Exception(
          'Format respons server tidak sesuai.',
        );
      }

      // Cari barang berdasarkan SKU.
      Map<String, dynamic>? foundProduct;

      final products = body['data'] as List;

      for (final item in products) {
        if (item is! Map) continue;

        final product = Map<String, dynamic>.from(item);

        final sku = product['sku']?.toString().trim();

        if (sku != null &&
            sku.toLowerCase() == barcode.toLowerCase()) {
          foundProduct = product;
          break;
        }
      }

      if (!context.mounted) return;

      // Jika barang ditemukan.
      if (foundProduct != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanResultScreen(
              product: foundProduct!,
              barcode: barcode,
            ),
          ),
        );
      } else {
        // Jika barang belum ditemukan,
        // arahkan ke halaman tambah SKU.
        final addResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddSkuScreen(
              scannedSku: barcode,
            ),
          ),
        );

        if (!context.mounted) return;

        if (addResult != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Kembali dari halaman tambah barang.',
              ),
              backgroundColor: _green,
            ),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mencari barang: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // NAVIGASI HALAMAN
  // =========================================================

  void _openHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          user: user,
        ),
      ),
      (route) => false,
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          user: user,
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          user: user,
        ),
      ),
      (route) => false,
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    15,
                    16,
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER

                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(
                              Icons.arrow_back,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'Scanner Gudang',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      const Center(
                        child: Text(
                          'Pindai barcode untuk memantau stok dan lokasi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF777777),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // FILTER TRANSAKSI

                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7F0E5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Inbound',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF587354),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Outbound',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF777777),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // GUDANG AKTIF

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE7E7E7),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Gudang Aktif',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF6C816A),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F2E5),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Text(
                                    'Siap',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Color(0xFF547250),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'WH-01 • Malang Jatim',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Row(
                              children: [
                                Expanded(
                                  child: _StockInfo(
                                    title: 'Stok aktif',
                                    value: '1.284',
                                  ),
                                ),
                                Expanded(
                                  child: _StockInfo(
                                    title: 'Stok kosong',
                                    value: '216',
                                  ),
                                ),
                                Expanded(
                                  child: _StockInfo(
                                    title: 'Scan hari ini',
                                    value: '38',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // BARCODE / SKU MANUAL

                      InkWell(
                        onTap: () => _showManualEntry(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE7E7E7),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2E8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.edit_note,
                                  color: _darkGreen,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 11),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Barcode / SKU',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Color(0xFF777777),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Pindai atau masukkan manual',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Tekan di sini untuk input SKU',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Color(0xFF8A928A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2E8),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Row(
                                  children: [
                                    Text(
                                      'Manual',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: _darkGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 10,
                                      color: _darkGreen,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 9),

                      // BUTTON SCAN DAN RIWAYAT

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ScannerCameraScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                ),
                                child: const Text(
                                  'Mulai Scan',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: OutlinedButton(
                                onPressed: () => _openHistory(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _green,
                                  side: const BorderSide(
                                    color: Color(0xFFE1E8DE),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                ),
                                child: const Text(
                                  'Riwayat Scan',
                                  style: TextStyle(
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _buildScanGuide(context),
                    ],
                  ),
                ),
              ),
            ),

            _buildBottomNavigation(context),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // PANDUAN SCANNER
  // =========================================================

  Widget _buildScanGuide(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE7E7E7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2E8),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: _darkGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tips Menggunakan Scanner',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ikuti langkah berikut agar proses scan berjalan lancar.',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _guideItem(
            number: '01',
            title: 'Pilih jenis transaksi',
            description:
                'Tentukan Inbound atau Outbound sesuai aktivitas gudang.',
          ),

          const SizedBox(height: 14),

          _guideItem(
            number: '02',
            title: 'Pindai barcode barang',
            description:
                'Tekan tombol Mulai Scan dan arahkan kamera ke barcode produk.',
          ),

          const SizedBox(height: 14),

          _guideItem(
            number: '03',
            title: 'Periksa hasil pemindaian',
            description:
                'Pastikan informasi barang sudah sesuai sebelum menyimpan transaksi.',
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5EE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.history,
                  color: _darkGreen,
                  size: 19,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Semua hasil pemindaian dapat dilihat melalui menu Riwayat.',
                    style: TextStyle(
                      fontSize: 10,
                      color: _darkGreen,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _openHistory(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Lihat',
                    style: TextStyle(
                      fontSize: 10,
                      color: _darkGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideItem({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 29,
          height: 29,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2E8),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: _darkGreen,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF777777),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  Widget _buildBottomNavigation(BuildContext context) {
    return Container(
      height: 82,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFECEEF1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomItem(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: false,
            onTap: () => _openHome(context),
          ),
          _bottomItem(
            icon: Icons.qr_code_scanner,
            label: 'Scanner',
            selected: true,
            onTap: () {},
          ),
          _bottomItem(
            icon: Icons.receipt_long_outlined,
            label: 'Riwayat',
            selected: false,
            onTap: () => _openHistory(context),
          ),
          _bottomItem(
            icon: Icons.person_outline,
            label: 'Profil',
            selected: false,
            onTap: () => _openProfile(context),
          ),
        ],
      ),
    );
  }

  Widget _bottomItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 27,
                color: selected
                    ? _green
                    : const Color(0xFF718096),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: selected
                      ? _green
                      : const Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: selected ? 7 : 0,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFF587B55),
                  borderRadius: BorderRadius.all(
                    Radius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// STOCK INFO
// =========================================================

class _StockInfo extends StatelessWidget {
  final String title;
  final String value;

  const _StockInfo({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 8,
            color: Color(0xFF777777),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
