
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ScanResultScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final String barcode;

  const ScanResultScreen({
    super.key,
    required this.product,
    required this.barcode,
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3001';

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001';
    }

    return 'http://localhost:3001';
  }

  late Map<String, dynamic> product;

  final TextEditingController quantityController =
      TextEditingController(text: '1');

  final TextEditingController noteController =
      TextEditingController();

  String movementType = 'in';
  bool isSaving = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    product = Map<String, dynamic>.from(widget.product);
  }

  @override
  void dispose() {
    quantityController.dispose();
    noteController.dispose();
    super.dispose();
  }

  // =============================================================
  // AUTHENTICATION
  // =============================================================

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception(
        'Token tidak ditemukan. Silakan login kembali.',
      );
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // =============================================================
  // PRODUCT DATA
  // =============================================================

  int get stock {
    final value = product['stock'];
    return int.tryParse(value.toString()) ?? 0;
  }

  String get productName =>
      product['name']?.toString() ?? 'Barang';

  String get sku =>
      product['sku']?.toString() ?? widget.barcode;

  String get unit =>
      product['unit']?.toString() ?? 'pcs';

  String get location {
    final value = product['location']?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }

    return 'Lokasi belum diatur';
  }

  // =============================================================
  // REFRESH DATA BARANG
  // =============================================================

  Future<void> _refreshProduct() async {
    final id = product['id'];

    if (id == null) {
      _showMessage('ID produk tidak ditemukan.');
      return;
    }

    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final headers = await _getAuthHeaders();

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/products'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Gagal mengambil data produk (${response.statusCode}).',
        );
      }

      final body = jsonDecode(response.body);

      if (body is! Map ||
          body['success'] != true ||
          body['data'] is! List) {
        throw Exception('Format respons produk tidak sesuai.');
      }

      final products = body['data'] as List;

      Map<String, dynamic>? updatedProduct;

      for (final item in products) {
        if (item is Map &&
            item['id'].toString() == id.toString()) {
          updatedProduct = Map<String, dynamic>.from(item);
          break;
        }
      }

      if (updatedProduct == null) {
        throw Exception('Produk tidak ditemukan.');
      }

      if (!mounted) return;

      setState(() {
        product = updatedProduct!;
      });
    } catch (e) {
      debugPrint('Refresh produk gagal: $e');

      if (mounted) {
        _showMessage('Gagal memperbarui data barang: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =============================================================
  // SIMPAN TRANSAKSI STOK
  // =============================================================

  Future<void> _saveMovement() async {
    if (isSaving) return;

    final quantity = int.tryParse(
      quantityController.text.trim(),
    );

    if (quantity == null || quantity <= 0) {
      _showMessage(
        'Jumlah harus berupa angka lebih dari 0.',
      );
      return;
    }

    if (movementType == 'out' && quantity > stock) {
      _showMessage(
        'Stok tidak mencukupi untuk transaksi keluar.',
      );
      return;
    }

    final productId = product['id'];

    if (productId == null) {
      _showMessage('ID produk tidak ditemukan.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final headers = await _getAuthHeaders();

      final now = DateTime.now();

      final transactionDate =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/stock-movements'),
            headers: headers,
            body: jsonEncode({
              'product_id': productId,
              'type': movementType,
              'quantity': quantity,
              'transaction_date': transactionDate,
              'note': noteController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if ((response.statusCode == 200 ||
              response.statusCode == 201) &&
          body is Map &&
          body['success'] == true) {
        final savedMovementType = movementType;

        // Perbarui stok setelah transaksi berhasil.
        await _refreshProduct();

        if (!mounted) return;

        quantityController.text = '1';
        noteController.clear();

        _showMessage(
          savedMovementType == 'in'
              ? 'Stok masuk berhasil disimpan!'
              : 'Stok keluar berhasil disimpan!',
        );
      } else {
        final message = body is Map
            ? body['message']?.toString()
            : null;

        throw Exception(
          message ?? 'Transaksi gagal disimpan.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Gagal menyimpan transaksi: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // =============================================================
  // MESSAGE
  // =============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // =============================================================
  // BUILD
  // =============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              height: 50,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 19,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Scanner Gudang',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: isLoading ? null : _refreshProduct,
                    icon: const Icon(
                      Icons.refresh,
                      color: Color(0xFF587B55),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // STATUS
                    _card(
                      color: const Color(0xFFE7F5E8),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Color(0xFF587B55),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scan Berhasil',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF587B55),
                                ),
                              ),
                              Text(
                                'Barang ditemukan di database',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Color(0xFF738174),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 9),

                    // PRODUCT
                    _card(
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F6F3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFF587B55),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  productName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF252936),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'SKU / Barcode: $sku',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF7D8794),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Stok tersedia',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFF87909D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F3E8),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '$stock $unit',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF587B55),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 9),

                    // LOCATION
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: Color(0xFF587B55),
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Lokasi Penyimpanan',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF587B55),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F3E7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              location,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF587B55),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _infoRow(
                            'Kategori',
                            product['category_name']?.toString() ??
                                product['category']?.toString() ??
                                'Belum diatur',
                          ),
                          const Divider(height: 16),
                          _infoRow(
                            'Harga barang',
                            'Rp ${product['price'] ?? 0}',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 9),

                    // BARCODE
                    _card(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.qr_code_2,
                            size: 18,
                            color: Color(0xFF7D8794),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Hasil barcode',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFF8A929E),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.barcode,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF30343B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // STOCK MOVEMENT FORM
                    const Text(
                      'Transaksi Stok',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF252936),
                      ),
                    ),

                    const SizedBox(height: 8),

                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Jenis transaksi',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Expanded(
                                child: _movementButton(
                                  label: 'Stok Masuk',
                                  icon: Icons.add_circle_outline,
                                  selected: movementType == 'in',
                                  onTap: () {
                                    setState(() {
                                      movementType = 'in';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _movementButton(
                                  label: 'Stok Keluar',
                                  icon: Icons.remove_circle_outline,
                                  selected: movementType == 'out',
                                  onTap: () {
                                    setState(() {
                                      movementType = 'out';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'Jumlah barang',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              hint: 'Masukkan jumlah barang',
                              suffix: unit,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Catatan (opsional)',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: noteController,
                            maxLines: 2,
                            decoration: _inputDecoration(
                              hint: 'Contoh: Pembelian barang baru',
                            ),
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : _saveMovement,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF587B55),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      movementType == 'in'
                                          ? 'Simpan Stok Masuk'
                                          : 'Simpan Stok Keluar',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.qr_code_scanner,
                          size: 15,
                        ),
                        label: const Text(
                          'Scan Lagi',
                          style: TextStyle(fontSize: 10),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF587B55),
                          side: const BorderSide(
                            color: Color(0xFF587B55),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // BOTTOM NAVIGATION
            Container(
              height: 56,
              color: Colors.white,
              child: Row(
                children: [
                  _bottomItem(
                    icon: Icons.home_outlined,
                    label: 'Beranda',
                    active: false,
                    onTap: () => Navigator.pop(context),
                  ),
                  _bottomItem(
                    icon: Icons.qr_code_scanner,
                    label: 'Scanner',
                    active: true,
                    onTap: () {},
                  ),
                  _bottomItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Riwayat',
                    active: false,
                    onTap: () {},
                  ),
                  _bottomItem(
                    icon: Icons.person_outline,
                    label: 'Profil',
                    active: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET HELPERS
  // =============================================================

  Widget _card({
    required Widget child,
    Color color = Colors.white,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            color: Color(0xFF87909D),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Color(0xFF30343B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _movementButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        style: const TextStyle(fontSize: 9),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected
            ? Colors.white
            : const Color(0xFF587B55),
        backgroundColor: selected
            ? const Color(0xFF587B55)
            : Colors.white,
        side: const BorderSide(
          color: Color(0xFF587B55),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    String? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 9),
      suffixText: suffix,
      suffixStyle: const TextStyle(fontSize: 9),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFFE1E6E2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFF587B55),
        ),
      ),
    );
  }

  Widget _bottomItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: active ? 34 : 25,
              height: active ? 28 : 22,
              decoration: active
                  ? const BoxDecoration(
                      color: Color(0xFFE2EDE2),
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Icon(
                icon,
                size: active ? 16 : 15,
                color: active
                    ? const Color(0xFF587B55)
                    : const Color(0xFF7E8793),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 7,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.w400,
                color: active
                    ? const Color(0xFF587B55)
                    : const Color(0xFF7E8793),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
