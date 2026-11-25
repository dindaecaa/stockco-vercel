
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../scanner/scanner_camera_screen.dart';

class BarangRusakScreen extends StatefulWidget {
  const BarangRusakScreen({super.key});

  @override
  State<BarangRusakScreen> createState() => _BarangRusakScreenState();
}

class _BarangRusakScreenState extends State<BarangRusakScreen> {
  static const Color _green = Color(0xFF587B55);
  static const Color _background = Color(0xFFF4F5F8);

  // =========================================================
  // BASE URL
  // =========================================================

  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3001';

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001';
    }

    return 'http://localhost:3001';
  }

  static String get _apiUrl => '$_baseUrl/api/damaged-items';
  static String get _productApiUrl => '$_baseUrl/api/products';

  // =========================================================
  // USER SESSION
  // =========================================================

  String? _token;
  int? _userId;

  bool get _isOwner => _userId == 8;

  Map<String, String> get _authHeaders => {
        'Accept': 'application/json',
        if (_token != null && _token!.isNotEmpty)
          'Authorization': 'Bearer $_token',
      };

  Map<String, String> get _jsonHeaders => {
        ..._authHeaders,
        'Content-Type': 'application/json',
      };

  Future<void> _muatSession() async {
    final prefs = await SharedPreferences.getInstance();

    final savedToken = prefs.getString('token');
    final savedUser = prefs.getString('user_data');

    int? userId;
    String? userToken;

    if (savedUser != null) {
      try {
        final decoded = jsonDecode(savedUser);

        if (decoded is Map) {
          userId = int.tryParse(
            decoded['id']?.toString() ?? '',
          );

          userToken = decoded['token']?.toString();
        }
      } catch (e) {
        debugPrint('Gagal membaca data user: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      _userId = userId;
      _token = savedToken?.isNotEmpty == true
          ? savedToken
          : userToken;
    });
  }

  // =========================================================
  // CONTROLLERS
  // =========================================================

  final _namaController = TextEditingController();
  final _skuController = TextEditingController();
  final _lokasiController = TextEditingController();
  final _jumlahController = TextEditingController();
  final _penyebabController = TextEditingController();
  final _catatanController = TextEditingController();

  // =========================================================
  // STATE
  // =========================================================

  String _foto = '';

  bool _barangDikenal = false;
  bool _sudahScan = false;
  bool _sedangMengirim = false;
  bool _sedangMemuat = false;
  bool _sedangScan = false;

  String? _laporanDiprosesId;

  final List<Map<String, dynamic>> _laporan = [];

  @override
  void initState() {
    super.initState();
    _inisialisasi();
  }

  Future<void> _inisialisasi() async {
    await _muatSession();

    if (!mounted) return;

    if (_token == null || _token!.isEmpty) {
      _pesan('Sesi login tidak ditemukan. Silakan login kembali.');
      return;
    }

    await _ambilLaporan();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _skuController.dispose();
    _lokasiController.dispose();
    _jumlahController.dispose();
    _penyebabController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  // =========================================================
  // AMBIL RIWAYAT LAPORAN
  // =========================================================

  Future<void> _ambilLaporan() async {
    if (_sedangMemuat) return;

    if (_token == null || _token!.isEmpty) {
      _pesan('Token login tidak ditemukan. Silakan login kembali.');
      return;
    }

    setState(() {
      _sedangMemuat = true;
    });

    try {
      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Gagal mengambil laporan (${response.statusCode}): ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map ||
          decoded['success'] != true ||
          decoded['data'] is! List) {
        throw Exception(
          decoded is Map
              ? decoded['message']?.toString() ??
                  'Format respons laporan tidak sesuai.'
              : 'Format respons laporan tidak valid.',
        );
      }

      final List data = decoded['data'];

      final laporanBaru = data.map<Map<String, dynamic>>((item) {
        final tanggal = item['created_at'] ?? item['tanggal'];

        return {
          'id': item['id']?.toString() ?? '',
          'nama': '${item['product_name'] ?? '-'}',
          'sku': '${item['product_sku'] ?? '-'}',
          'lokasi': '${item['location'] ?? '-'}',
          'jumlah': '${item['quantity'] ?? 0}',
          'penyebab': '${item['reason'] ?? '-'}',
          'catatan': '${item['note'] ?? '-'}',
          'status': '${item['status'] ?? 'Belum ditindaklanjuti'}',
          'foto': item['photo_key'] == null
              ? 'Belum ada foto'
              : '${item['photo_key']}',
          'tanggal': tanggal == null ? '-' : tanggal.toString(),
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _laporan
          ..clear()
          ..addAll(laporanBaru);
      });
    } catch (e) {
      if (!mounted) return;

      _pesan('Gagal mengambil riwayat laporan: $e');
      debugPrint('Ambil laporan barang rusak error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _sedangMemuat = false;
        });
      }
    }
  }

  // =========================================================
  // SCAN BARCODE DAN CARI PRODUK
  // =========================================================

  Future<void> _scanBarang() async {
    if (_sedangMengirim || _sedangScan) return;

    if (_token == null || _token!.isEmpty) {
      _pesan('Sesi login tidak ditemukan. Silakan login kembali.');
      return;
    }

    setState(() {
      _sedangScan = true;
    });

    try {
      final barcode = await Navigator.push<String>(
        context,
        MaterialPageRoute<String>(
          builder: (_) => const ScannerCameraScreen(
            returnBarcodeOnly: true,
          ),
        ),
      );

      if (!mounted) return;

      if (barcode == null || barcode.trim().isEmpty) return;

      _pesan('Memeriksa barcode ke database...');

      final response = await http
          .get(
            Uri.parse(_productApiUrl),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Gagal mengambil data produk (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map ||
          decoded['success'] != true ||
          decoded['data'] is! List) {
        throw Exception(
          decoded is Map
              ? decoded['message']?.toString() ??
                  'Format respons produk tidak sesuai.'
              : 'Format respons produk tidak valid.',
        );
      }

      final List products = decoded['data'];

      Map<String, dynamic>? foundProduct;

      for (final item in products) {
        if (item is! Map) continue;

        final product = Map<String, dynamic>.from(item);
        final sku = product['sku']?.toString().trim();

        if (sku != null &&
            sku.toLowerCase() == barcode.trim().toLowerCase()) {
          foundProduct = product;
          break;
        }
      }

      if (!mounted) return;

      if (foundProduct == null) {
        setState(() {
          _namaController.clear();
          _skuController.clear();
          _lokasiController.clear();
          _barangDikenal = false;
          _sudahScan = false;
        });

        _pesan(
          'Barcode tidak ditemukan dalam database produk. '
          'Silakan scan barang yang sudah terdaftar.',
        );
        return;
      }

      setState(() {
        _namaController.text =
            foundProduct!['name']?.toString() ?? '';

        _skuController.text =
            foundProduct['sku']?.toString() ?? barcode;

        _lokasiController.text =
            foundProduct['location']?.toString() ?? '';

        _barangDikenal = true;
        _sudahScan = true;
      });

      _pesan('Barang ditemukan: ${foundProduct['name'] ?? 'Barang'}');
    } catch (e) {
      if (!mounted) return;

      _pesan('Gagal memeriksa barcode: $e');
      debugPrint('Scan barang rusak error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _sedangScan = false;
        });
      }
    }
  }

  // =========================================================
  // SIMPAN LAPORAN
  // =========================================================

  Future<void> _simpanLaporan() async {
    if (!_sudahScan ||
        !_barangDikenal ||
        _skuController.text.trim().isEmpty ||
        _namaController.text.trim().isEmpty) {
      _pesan(
        'Scan barcode barang yang sudah terdaftar terlebih dahulu.',
      );
      return;
    }

    if (_jumlahController.text.trim().isEmpty ||
        _penyebabController.text.trim().isEmpty) {
      _pesan(
        'Jumlah barang rusak dan penyebab kerusakan wajib diisi.',
      );
      return;
    }

    final jumlah = int.tryParse(_jumlahController.text.trim());

    if (jumlah == null || jumlah <= 0) {
      _pesan('Jumlah rusak harus berupa angka lebih dari 0.');
      return;
    }

    if (_sedangMengirim || _sedangScan) return;

    if (_token == null || _token!.isEmpty) {
      _pesan('Sesi login tidak ditemukan. Silakan login kembali.');
      return;
    }

    setState(() {
      _sedangMengirim = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: _jsonHeaders,
            body: jsonEncode({
              'product_name': _namaController.text.trim(),
              'product_sku': _skuController.text.trim(),
              'location': _lokasiController.text.trim(),
              'quantity': jumlah,
              'reason': _penyebabController.text.trim(),
              'note': _catatanController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map &&
          decoded['success'] == true) {
        _resetForm();

        setState(() {});

        await _ambilLaporan();

        if (!mounted) return;

        _pesan('Laporan berhasil dikirim ke server!');
      } else {
        final message =
            decoded is Map ? decoded['message']?.toString() : null;

        _pesan(message ?? 'Gagal mengirim laporan.');
      }
    } catch (e) {
      if (!mounted) return;

      _pesan('Gagal menghubungi server: $e');
      debugPrint('Simpan laporan barang rusak error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _sedangMengirim = false;
        });
      }
    }
  }

  // =========================================================
  // OWNER: ACC / TOLAK LAPORAN
  // =========================================================

  Future<void> _ubahStatusLaporan(
    String laporanId,
    String statusBaru,
  ) async {
    if (!_isOwner) {
      _pesan('Hanya Owner yang dapat mengubah status laporan.');
      return;
    }

    if (_token == null || _token!.isEmpty) {
      _pesan('Sesi login tidak ditemukan. Silakan login kembali.');
      return;
    }

    if (_laporanDiprosesId != null) return;

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isApprove = statusBaru == 'Disetujui';

        return AlertDialog(
          title: Text(
            isApprove ? 'Setujui Laporan?' : 'Tolak Laporan?',
          ),
          content: Text(
            isApprove
                ? 'Apakah kamu yakin ingin menyetujui laporan barang rusak ini?'
                : 'Apakah kamu yakin ingin menolak laporan barang rusak ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isApprove ? _green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(isApprove ? 'Ya, Setujui' : 'Ya, Tolak'),
            ),
          ],
        );
      },
    );

    if (konfirmasi != true || !mounted) return;

    setState(() {
      _laporanDiprosesId = laporanId;
    });

    try {
      final response = await http
          .patch(
            Uri.parse('$_apiUrl/$laporanId/status'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'status': statusBaru,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map &&
          decoded['success'] == true) {
        _pesan(
          statusBaru == 'Disetujui'
              ? 'Laporan berhasil disetujui.'
              : 'Laporan berhasil ditolak.',
        );

        await _ambilLaporan();
      } else {
        final message =
            decoded is Map ? decoded['message']?.toString() : null;

        _pesan(message ?? 'Gagal mengubah status laporan.');
      }
    } catch (e) {
      if (!mounted) return;

      _pesan('Gagal mengubah status laporan: $e');
      debugPrint('Ubah status barang rusak error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _laporanDiprosesId = null;
        });
      }
    }
  }

  // =========================================================
  // RESET FORM
  // =========================================================

  void _resetForm() {
    _namaController.clear();
    _skuController.clear();
    _lokasiController.clear();
    _jumlahController.clear();
    _penyebabController.clear();
    _catatanController.clear();

    _foto = '';
    _barangDikenal = false;
    _sudahScan = false;
  }

  // =========================================================
  // PESAN
  // =========================================================

  void _pesan(String pesan) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(pesan),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // =========================================================
  // WARNA STATUS
  // =========================================================

  Color _statusColor(String status) {
    switch (status) {
      case 'Selesai':
      case 'Disetujui':
        return Colors.green;
      case 'Dalam proses':
        return Colors.orange;
      case 'Ditolak':
        return Colors.red;
      default:
        return Colors.redAccent;
    }
  }

  // =========================================================
  // JUDUL SECTION
  // =========================================================

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // INPUT FIELD
  // =========================================================

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            readOnly: readOnly,
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor:
                  readOnly ? Colors.grey.shade100 : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: _green,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FORM LAPORAN
  // =========================================================

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Form Laporan Barang Rusak',
            subtitle:
                'Scan barcode untuk mengambil data barang secara otomatis.',
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _sedangMengirim || _sedangScan ? null : _scanBarang,
              icon: _sedangScan
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.qr_code_scanner),
              label: Text(
                _sedangScan
                    ? 'Memeriksa Barcode...'
                    : 'Scan Barcode Barang',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          if (_sudahScan)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data barang berhasil ditemukan dan terisi otomatis.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          _field(
            label: 'Nama Barang',
            controller: _namaController,
            hint: 'Otomatis terisi setelah scan',
            readOnly: true,
            suffixIcon: const Icon(Icons.lock_outline, size: 18),
          ),
          _field(
            label: 'SKU / Barcode',
            controller: _skuController,
            hint: 'Otomatis terisi setelah scan',
            readOnly: true,
            suffixIcon: const Icon(Icons.lock_outline, size: 18),
          ),
          _field(
            label: 'Lokasi Barang',
            controller: _lokasiController,
            hint: 'Otomatis dari data produk',
            readOnly: true,
            suffixIcon: const Icon(Icons.lock_outline, size: 18),
          ),
          _field(
            label: 'Jumlah Barang Rusak',
            controller: _jumlahController,
            hint: 'Contoh: 2',
            keyboardType: TextInputType.number,
          ),
          _field(
            label: 'Penyebab Kerusakan',
            controller: _penyebabController,
            hint: 'Contoh: jatuh, terkena air, tidak berfungsi',
            maxLines: 2,
          ),
          const Text(
            'Bukti Foto',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          InkWell(
            onTap: () {
              _pesan(
                'Pemilihan foto belum dihubungkan. '
                'Fitur ini dapat ditambahkan menggunakan image_picker.',
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    color: _green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _foto.isEmpty
                          ? 'Tambah bukti foto (belum aktif)'
                          : _foto,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _field(
            label: 'Catatan Tambahan',
            controller: _catatanController,
            hint: 'Opsional',
            maxLines: 3,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.pending_actions,
                  color: Colors.redAccent,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Status awal otomatis: Belum ditindaklanjuti. '
                    'Persetujuan atau penolakan laporan dilakukan oleh Owner.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _sedangMengirim
                      ? null
                      : () {
                          setState(_resetForm);
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed:
                      _sedangMengirim || _sedangScan
                          ? null
                          : _simpanLaporan,
                  icon: _sedangMengirim
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _sedangMengirim ? 'Mengirim...' : 'Simpan Laporan',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // RIWAYAT BARANG RUSAK
  // =========================================================

  Widget _buildRiwayat() {
    final totalRusak = _laporan.fold<int>(
      0,
      (total, item) =>
          total + (int.tryParse(item['jumlah']?.toString() ?? '0') ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionTitle('Riwayat Barang Rusak'),
            ),
            Text(
              '${_laporan.length} laporan',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: _green,
                size: 27,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Total unit barang rusak dilaporkan'),
              ),
              Text(
                '$totalRusak unit',
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        if (_sedangMemuat)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_laporan.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 42,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Belum ada laporan barang rusak',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan barang dan isi detail kerusakannya untuk membuat laporan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          ..._laporan.map((item) {
            final status =
                item['status']?.toString() ?? 'Belum ditindaklanjuti';

            final color = _statusColor(status);
            final laporanId = item['id']?.toString() ?? '';
            final isPending = status == 'Belum ditindaklanjuti';
            final sedangDiproses = _laporanDiprosesId == laporanId;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: _green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['nama']?.toString() ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${item['sku']} • ${item['lokasi']}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${item['jumlah']} unit',
                        style: const TextStyle(
                          color: _green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Penyebab: ${item['penyebab']}'),
                  const SizedBox(height: 4),
                  Text(
                    'Catatan: ${item['catatan']}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item['tanggal']?.toString() ?? '-',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Bukti: ${item['foto']}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),

                  // Tombol hanya ditampilkan untuk Owner.
                  if (_isOwner && isPending && laporanId.isNotEmpty) ...[
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: sedangDiproses ||
                                    _laporanDiprosesId != null
                                ? null
                                : () => _ubahStatusLaporan(
                                      laporanId,
                                      'Ditolak',
                                    ),
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                            ),
                            label: const Text('Tolak'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(
                                vertical: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: sedangDiproses ||
                                    _laporanDiprosesId != null
                                ? null
                                : () => _ubahStatusLaporan(
                                      laporanId,
                                      'Disetujui',
                                    ),
                            icon: sedangDiproses
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check,
                                    size: 18,
                                  ),
                            label: Text(
                              sedangDiproses ? 'Memproses...' : 'ACC',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  // =========================================================
  // MAIN SCREEN
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Barang Rusak',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _sedangMemuat ? null : _ambilLaporan,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang laporan',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _ambilLaporan,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.report_problem_outlined,
                      color: Colors.white,
                      size: 35,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Laporan Barang Rusak',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Scan barang terlebih dahulu, lalu lengkapi informasi kerusakan.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildFormCard(),
              const SizedBox(height: 24),
              _buildRiwayat(),
            ],
          ),
        ),
      ),
    );
  }
}
