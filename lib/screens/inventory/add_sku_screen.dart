
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AddSkuScreen extends StatefulWidget {
  final String? scannedSku;

  const AddSkuScreen({
    super.key,
    this.scannedSku,
  });

  @override
  State<AddSkuScreen> createState() => _AddSkuScreenState();
}

class _AddSkuScreenState extends State<AddSkuScreen> {
  // Flutter Web / Chrome dan Android Emulator.
  static String get baseUrl => kIsWeb
      ? 'http://localhost:3001'
      : 'http://10.0.2.2:3001';

  static const Color primaryGreen = Color(0xFF587B55);
  static const Color darkGreen = Color(0xFF365B3A);
  static const Color lightGreen = Color(0xFFEAF3E7);
  static const Color backgroundColor = Color(0xFFF5F8F4);
  static const Color borderColor = Color(0xFFDDE7DA);
  static const Color textColor = Color(0xFF263328);
  static const Color hintColor = Color(0xFF9AA79A);

  final skuController = TextEditingController();
  final nameController = TextEditingController();
  final resellerController = TextEditingController();
  final locationController = TextEditingController();
  final noteController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController(text: '0');

  bool showSkuError = false;
  bool isSaving = false;

  String? selectedCategory;
  String? selectedUnit;

  final List<String> categories = [
    'Aksesori HP',
    'Kabel & Konektor',
    'Perangkat Jaringan',
    'Audio',
    'Pengisi Daya',
  ];

  final List<String> units = [
    'Pcs',
    'Unit',
    'Box',
    'Pack',
    'Meter',
    'Roll',
  ];

  @override
  void initState() {
    super.initState();
    skuController.text = widget.scannedSku ?? '';
  }

  @override
  void dispose() {
    skuController.dispose();
    nameController.dispose();
    resellerController.dispose();
    locationController.dispose();
    noteController.dispose();
    priceController.dispose();
    stockController.dispose();
    super.dispose();
  }

  // ======================================================
  // TOKEN DAN HEADER API
  // ======================================================

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Token login tidak ditemukan. Silakan login kembali.',
      );
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ======================================================
  // SIMPAN PRODUK
  // ======================================================

  Future<void> saveSku() async {
    if (isSaving) return;

    final sku = skuController.text.trim();
    final name = nameController.text.trim();
    final resellerName = resellerController.text.trim();
    final priceText = priceController.text.trim();
    final stockText = stockController.text.trim();

    final price = double.tryParse(priceText);
    final stock = int.tryParse(stockText);

    if (sku.isEmpty) {
      setState(() {
        showSkuError = true;
      });

      _showMessage(
        'Kode SKU / Barcode wajib diisi.',
        isError: true,
      );
      return;
    }

    if (name.isEmpty) {
      _showMessage(
        'Nama barang wajib diisi.',
        isError: true,
      );
      return;
    }

    if (resellerName.isEmpty) {
      _showMessage(
        'Nama reseller wajib diisi.',
        isError: true,
      );
      return;
    }

    if (selectedCategory == null) {
      _showMessage(
        'Silakan pilih kategori barang.',
        isError: true,
      );
      return;
    }

    if (selectedUnit == null) {
      _showMessage(
        'Silakan pilih satuan barang.',
        isError: true,
      );
      return;
    }

    if (price == null || price < 0) {
      _showMessage(
        'Harga barang tidak valid.',
        isError: true,
      );
      return;
    }

    if (stock == null || stock < 0) {
      _showMessage(
        'Stok awal harus berupa angka bulat dan tidak boleh negatif.',
        isError: true,
      );
      return;
    }

    setState(() {
      isSaving = true;
      showSkuError = false;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/products'),
            headers: await _getHeaders(),
            body: jsonEncode({
              'sku': sku,
              'name': name,
              'reseller_name': resellerName,
              'category': selectedCategory,
              'unit': selectedUnit!.toLowerCase(),
              'location': locationController.text.trim(),
              'description': noteController.text.trim(),
              'price': price,
              'stock': stock,
              'minimum_stock': 5,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      Map<String, dynamic> result;

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          result = decoded;
        } else {
          throw const FormatException(
            'Format respons server tidak sesuai.',
          );
        }
      } catch (_) {
        _showMessage(
          'Respons server tidak dapat dibaca. Periksa backend.',
          isError: true,
        );
        return;
      }

      if ((response.statusCode == 200 ||
              response.statusCode == 201) &&
          result['success'] == true) {
        _showMessage(
          'Barang berhasil disimpan ke database!',
          isError: false,
        );

        await Future.delayed(
          const Duration(milliseconds: 500),
        );

        if (!mounted) return;

        Navigator.pop(context, name);
      } else {
        final message = result['message']?.toString() ??
            'Gagal menyimpan barang.';

        _showMessage(
          message,
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().contains('Token login')
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Tidak dapat terhubung ke server. Pastikan backend aktif.',
        isError: true,
      );

      debugPrint('Save SKU error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // ======================================================
  // SNACKBAR
  // ======================================================

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor:
              isError ? const Color(0xFFB94B4B) : darkGreen,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ======================================================
  // PICKER KATEGORI DAN SATUAN
  // ======================================================

  void showPicker({
    required String title,
    required List<String> items,
    required String? selected,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDE5DA),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 14),
                ...items.map((item) {
                  final isSelected = selected == item;

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      onSelected(item);
                      Navigator.pop(sheetContext);
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? lightGreen
                            : const Color(0xFFF8FAF7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? primaryGreen
                              : const Color(0xFFE8EEE6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ),
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.chevron_right,
                            size: 19,
                            color: isSelected
                                ? primaryGreen
                                : hintColor,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 5),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                    },
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ======================================================
  // BUILD
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  16,
                  17,
                  16,
                  25,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntro(),
                    const SizedBox(height: 18),

                    // INFORMASI BARANG
                    _buildSection(
                      title: 'Informasi Barang',
                      subtitle: 'Masukkan identitas barang',
                      icon: Icons.inventory_2_outlined,
                      children: [
                        _buildFieldLabel(
                          'Kode SKU / Barcode',
                          required: true,
                        ),
                        const SizedBox(height: 7),
                        _buildTextField(
                          controller: skuController,
                          hintText: 'Barcode otomatis dari scanner',
                          prefixIcon: Icons.qr_code_2,
                          hasError: showSkuError,
                          onChanged: (value) {
                            if (value.trim().isNotEmpty &&
                                showSkuError) {
                              setState(() {
                                showSkuError = false;
                              });
                            }
                          },
                        ),
                        if (showSkuError)
                          const Padding(
                            padding: EdgeInsets.only(
                              top: 6,
                              left: 4,
                            ),
                            child: Text(
                              'Kode SKU wajib diisi.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFB94B4B),
                              ),
                            ),
                          ),
                        const SizedBox(height: 15),
                        _buildFieldLabel(
                          'Nama Barang',
                          required: true,
                        ),
                        const SizedBox(height: 7),
                        _buildTextField(
                          controller: nameController,
                          hintText: 'Contoh: Laptop Asus',
                          prefixIcon: Icons.inventory_outlined,
                        ),
                        const SizedBox(height: 15),
                        _buildFieldLabel(
                          'Nama Reseller',
                          required: true,
                        ),
                        const SizedBox(height: 7),
                        _buildTextField(
                          controller: resellerController,
                          hintText: 'Masukkan nama reseller',
                          prefixIcon: Icons.storefront_outlined,
                        ),
                        const SizedBox(height: 15),
                        _buildFieldLabel(
                          'Kategori',
                          required: true,
                        ),
                        const SizedBox(height: 7),
                        _buildSelectionField(
                          value: selectedCategory,
                          hintText: 'Pilih kategori barang',
                          icon: Icons.category_outlined,
                          onTap: () {
                            showPicker(
                              title: 'Pilih Kategori',
                              items: categories,
                              selected: selectedCategory,
                              onSelected: (value) {
                                setState(() {
                                  selectedCategory = value;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 15),
                        _buildFieldLabel(
                          'Satuan',
                          required: true,
                        ),
                        const SizedBox(height: 7),
                        _buildSelectionField(
                          value: selectedUnit,
                          hintText: 'Pilih satuan barang',
                          icon: Icons.straighten_outlined,
                          onTap: () {
                            showPicker(
                              title: 'Pilih Satuan',
                              items: units,
                              selected: selectedUnit,
                              onSelected: (value) {
                                setState(() {
                                  selectedUnit = value;
                                });
                              },
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // INFORMASI STOK
                    _buildSection(
                      title: 'Informasi Stok',
                      subtitle: 'Atur harga dan jumlah persediaan',
                      icon: Icons.warehouse_outlined,
                      children: [
                        _buildFieldLabel(
                          'Harga Barang',
                          required: true,
                        ),
                        const SizedBox(height: 7),
                        _buildTextField(
                          controller: priceController,
                          hintText: 'Contoh: 150000',
                          prefixIcon: Icons.payments_outlined,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        _buildFieldLabel(
                          'Stok Awal',
                          required: true,
                        ),
                        const SizedBox(height: 7),
                        _buildTextField(
                          controller: stockController,
                          hintText: 'Masukkan jumlah stok awal',
                          prefixIcon: Icons.layers_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: lightGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 17,
                                color: darkGreen,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Batas minimum stok awal otomatis diatur menjadi 5.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: darkGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // INFORMASI TAMBAHAN
                    _buildSection(
                      title: 'Informasi Tambahan',
                      subtitle: 'Lokasi dan catatan barang',
                      icon: Icons.description_outlined,
                      children: [
                        _buildFieldLabel('Lokasi Penyimpanan'),
                        const SizedBox(height: 7),
                        _buildTextField(
                          controller: locationController,
                          hintText: 'Contoh: Rak A-12',
                          prefixIcon: Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 15),
                        _buildFieldLabel(
                          'Catatan',
                          optional: true,
                        ),
                        const SizedBox(height: 7),
                        _buildTextField(
                          controller: noteController,
                          hintText: 'Tulis catatan barang di sini...',
                          prefixIcon: Icons.notes_outlined,
                          maxLines: 3,
                          minLines: 3,
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // TOMBOL SIMPAN
                    SizedBox(
                      width: double.infinity,
                      height: 49,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : saveSku,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFFA7B9A3),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.save_outlined,
                                    size: 19,
                                  ),
                                  SizedBox(width: 9),
                                  Text(
                                    'Simpan Barang',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        '* Wajib diisi untuk menyimpan barang',
                        style: TextStyle(
                          fontSize: 10,
                          color: hintColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // ======================================================
  // HEADER
  // ======================================================

  Widget _buildHeader() {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 17),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE8EEE6),
          ),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: darkGreen,
              ),
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Text(
              'Tambah SKU',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: darkGreen,
                ),
                SizedBox(width: 5),
                Text(
                  'Stock.co',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: darkGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // INTRO
  // ======================================================

  Widget _buildIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.add_box_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daftarkan Barang Baru',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Lengkapi informasi barang dan reseller untuk masuk ke inventaris.',
                  style: TextStyle(
                    color: Color(0xFFE3EDE1),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // SECTION FORM
  // ======================================================

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: darkGreen,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ...children,
        ],
      ),
    );
  }

  // ======================================================
  // LABEL
  // ======================================================

  Widget _buildFieldLabel(
    String label, {
    bool required = false,
    bool optional = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              color: Color(0xFFB94B4B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (optional) ...[
          const SizedBox(width: 6),
          const Text(
            '(Opsional)',
            style: TextStyle(
              fontSize: 10,
              color: hintColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  // ======================================================
  // TEXT FIELD
  // ======================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    int? minLines,
    bool hasError = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 12,
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 11,
          color: hintColor,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(
            left: 12,
            right: 9,
          ),
          child: Icon(
            prefixIcon,
            size: 18,
            color: primaryGreen,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        filled: true,
        fillColor: const Color(0xFFFAFCF9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(
            color: hasError
                ? const Color(0xFFB94B4B)
                : borderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(
            color: hasError
                ? const Color(0xFFB94B4B)
                : borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(
            color: hasError
                ? const Color(0xFFB94B4B)
                : primaryGreen,
            width: 1.4,
          ),
        ),
      ),
    );
  }

  // ======================================================
  // SELECTION FIELD
  // ======================================================

  Widget _buildSelectionField({
    required String? value,
    required String hintText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 47,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFCF9),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: primaryGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ?? hintText,
                style: TextStyle(
                  fontSize: 11,
                  color: value == null ? hintColor : textColor,
                  fontWeight: value == null
                      ? FontWeight.w400
                      : FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 21,
              color: primaryGreen,
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // BOTTOM NAVIGATION
  // ======================================================

  Widget _buildBottomNavigation() {
    return Container(
      height: 66,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE8EEE6),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomItem(
            Icons.home_outlined,
            'Home',
          ),
          _bottomItem(
            Icons.qr_code_scanner,
            'Scanner',
          ),
          _bottomItem(
            Icons.receipt_long_outlined,
            'Riwayat',
          ),
          _bottomItem(
            Icons.person_outline,
            'Profil',
          ),
        ],
      ),
    );
  }

  Widget _bottomItem(
    IconData icon,
    String label,
  ) {
    return SizedBox(
      width: 65,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF829082),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF829082),
            ),
          ),
        ],
      ),
    );
  }
}
