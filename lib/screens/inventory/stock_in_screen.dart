
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_data.dart';
import '../home/home_screen.dart';
import '../scanner/scanner_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import 'add_sku_screen.dart';

class StockInScreen extends StatefulWidget {
  final UserData user;

  StockInScreen({
    super.key,
    UserData? user,
  }) : user = user ??
            UserData(
              name: 'Zefanya',
              email: '',
            );

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  static const Color _green = Color(0xFF587B55);
  static const Color _red = Color(0xFFFF5964);

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:3001';

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001';
    }

    return 'http://localhost:3001';
  }

  Future<Map<String, String>> getAuthHeaders({
    bool withJson = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userToken = widget.user.token;
    final token = (userToken != null && userToken.isNotEmpty)
    ? userToken
    : prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception(
        'Sesi login tidak ditemukan. Silakan login kembali.',
      );
    }

    return {
      'Accept': 'application/json',
      if (withJson) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> suppliers = [];

  int? selectedProductId;
  int? selectedSupplierId;

  DateTime selectedDate = DateTime.now();

  final TextEditingController quantityController =
      TextEditingController();

  final TextEditingController noteController =
      TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  bool showError = false;
  bool isSaved = false;

  String errorMessage = '';

  Map<String, dynamic>? get selectedProduct {
    for (final product in products) {
      if (int.tryParse(product['id'].toString()) == selectedProductId) {
        return product;
      }
    }
    return null;
  }

  Map<String, dynamic>? get selectedSupplier {
    for (final supplier in suppliers) {
      if (int.tryParse(supplier['id'].toString()) == selectedSupplierId) {
        return supplier;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  @override
  void dispose() {
    quantityController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> loadInitialData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final headers = await getAuthHeaders();

      final responses = await Future.wait([
        http.get(
          Uri.parse('$baseUrl/api/products'),
          headers: headers,
        ),
        http.get(
          Uri.parse('$baseUrl/api/suppliers'),
          headers: headers,
        ),
      ]).timeout(const Duration(seconds: 20));

      final productResponse = responses[0];
      final supplierResponse = responses[1];

      final productJson = jsonDecode(productResponse.body);
      final supplierJson = jsonDecode(supplierResponse.body);

      if (productResponse.statusCode != 200) {
        final message = productJson is Map
            ? productJson['message']?.toString()
            : null;
        throw Exception(message ?? 'Gagal mengambil data produk.');
      }

      if (supplierResponse.statusCode != 200) {
        final message = supplierJson is Map
            ? supplierJson['message']?.toString()
            : null;
        throw Exception(message ?? 'Gagal mengambil data supplier.');
      }

      if (productJson is! Map ||
          productJson['success'] != true ||
          productJson['data'] is! List) {
        throw Exception('Format data produk tidak sesuai.');
      }

      if (supplierJson is! Map ||
          supplierJson['success'] != true ||
          supplierJson['data'] is! List) {
        throw Exception('Format data supplier tidak sesuai.');
      }

      final loadedProducts = (productJson['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final loadedSuppliers = (supplierJson['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      setState(() {
        products = loadedProducts;
        suppliers = loadedSuppliers;
        isLoading = false;

        if (!products.any(
          (item) =>
              int.tryParse(item['id'].toString()) == selectedProductId,
        )) {
          selectedProductId = null;
        }

        if (!suppliers.any(
          (item) =>
              int.tryParse(item['id'].toString()) == selectedSupplierId,
        )) {
          selectedSupplierId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> addNewSku() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddSkuScreen(),
      ),
    );

    if (!mounted) return;

    if (result != null && result.trim().isNotEmpty) {
      await loadInitialData();

      if (!mounted) return;

      final matchedProduct = products.where(
        (product) =>
            product['name']?.toString().toLowerCase() ==
            result.trim().toLowerCase(),
      );

      if (matchedProduct.isNotEmpty) {
        setState(() {
          selectedProductId =
              int.tryParse(matchedProduct.first['id'].toString());
          showError = false;
          isSaved = false;
        });
      }
    }
  }

  Future<void> saveStockIn() async {
    final product = selectedProduct;
    final quantity = int.tryParse(quantityController.text.trim());

    if (product == null || quantity == null || quantity <= 0) {
      setState(() {
        showError = true;
        isSaved = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pilih barang dan masukkan jumlah stok yang valid.',
          ),
          backgroundColor: _red,
        ),
      );
      return;
    }

    setState(() {
      showError = false;
      isSaving = true;
      isSaved = false;
    });

    try {
      final body = {
        'product_id': product['id'],
        'supplier_id': selectedSupplierId,
        'type': 'in',
        'quantity': quantity,
        'transaction_date': formatApiDate(selectedDate),
        'note': noteController.text.trim(),
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/stock-movements'),
            headers: await getAuthHeaders(withJson: true),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      final responseJson = jsonDecode(response.body);

      if (response.statusCode != 201 ||
          responseJson is! Map ||
          responseJson['success'] != true) {
        final message = responseJson is Map
            ? responseJson['message']?.toString()
            : null;

        throw Exception(
          message ?? 'Transaksi stok masuk gagal disimpan.',
        );
      }

      if (!mounted) return;

      setState(() {
        isSaving = false;
        isSaved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            responseJson['message']?.toString() ??
                'Stok masuk berhasil disimpan.',
          ),
          backgroundColor: const Color(0xFF20C769),
        ),
      );

      await loadInitialData();

      if (!mounted) return;

      setState(() {
        isSaved = true;
        quantityController.clear();
        noteController.clear();
        selectedProductId = null;
        selectedSupplierId = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
        isSaved = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: _red,
        ),
      );
    }
  }

  void showProductPicker() {
    if (isLoading) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Barang',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text('Belum ada data barang.'),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final id = int.tryParse(
                          product['id'].toString(),
                        );

                        if (id == null) {
                          return const SizedBox.shrink();
                        }

                        final isSelected = selectedProductId == id;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF0E7),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 19,
                              color: _green,
                            ),
                          ),
                          title: Text(
                            product['name']?.toString() ?? 'Tanpa nama',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'SKU: ${product['sku'] ?? '-'}  •  Stok: ${product['stock'] ?? 0} ${product['unit'] ?? 'pcs'}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: _green,
                                )
                              : const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                ),
                          onTap: () {
                            setState(() {
                              selectedProductId = id;
                              showError = false;
                              isSaved = false;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showSupplierPicker() {
    if (isLoading) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Pemasok',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.grey,
                  ),
                  title: const Text('Tanpa pemasok'),
                  trailing: selectedSupplierId == null
                      ? const Icon(Icons.check_circle, color: _green)
                      : null,
                  onTap: () {
                    setState(() {
                      selectedSupplierId = null;
                      isSaved = false;
                    });
                    Navigator.pop(context);
                  },
                ),
                if (suppliers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Belum ada data pemasok.'),
                  )
                else
                  ...suppliers.map((supplier) {
                    final id = int.tryParse(
                      supplier['id'].toString(),
                    );

                    if (id == null) {
                      return const SizedBox.shrink();
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF0E7),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.business_outlined,
                          size: 19,
                          color: _green,
                        ),
                      ),
                      title: Text(
                        supplier['name']?.toString() ?? 'Tanpa nama',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: selectedSupplierId == id
                          ? const Icon(
                              Icons.check_circle,
                              color: _green,
                            )
                          : const Icon(
                              Icons.chevron_right,
                              size: 18,
                            ),
                      onTap: () {
                        setState(() {
                          selectedSupplierId = id;
                          isSaved = false;
                        });
                        Navigator.pop(context);
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() {
        selectedDate = picked;
        isSaved = false;
      });
    }
  }

  String formatDate(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String formatApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  void navigateBottom(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ScannerScreen()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HistoryScreen()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: Color(0xFF2F3742),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Text(
                    'Stok Masuk',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const Spacer(),
                  if (isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _green,
                      ),
                    )
                  else
                    IconButton(
                      onPressed: loadInitialData,
                      icon: const Icon(
                        Icons.refresh,
                        size: 20,
                        color: _green,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(7, 10, 7, 20),
                child: Column(
                  children: [
                    if (errorMessage.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEEE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              errorMessage,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _red,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: loadInitialData,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Coba lagi'),
                            ),
                          ],
                        ),
                      ),
                    _buildForm(),
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

  Widget _buildForm() {
    final product = selectedProduct;
    final supplier = selectedSupplier;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(7, 9, 7, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: showError && product == null
                  ? const Color(0xFFFFEEEE)
                  : Colors.white,
              border: Border.all(
                color: showError && product == null
                    ? _red
                    : const Color(0xFFE7E9ED),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 37,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: Color(0xFF59677A),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Barang',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF30343B),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 24,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : addNewSku,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text(
                              'Tambah',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                InkWell(
                  onTap: showProductPicker,
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: isLoading
                          ? const Text(
                              'Memuat data barang...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB6BBC3),
                              ),
                            )
                          : product == null
                              ? const Text(
                                  'Tidak ada barang yang dipilih',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB6BBC3),
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      product['name']?.toString() ?? '-',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF30343B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'SKU: ${product['sku'] ?? '-'}  •  Stok saat ini: ${product['stock'] ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF788392),
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showError && product == null)
            _errorText('Pilih Barang terlebih dahulu'),
          const SizedBox(height: 8),
          _formRow(
            icon: Icons.person_outline,
            title: supplier?['name']?.toString() ?? 'Pilih Pemasok',
            onTap: showSupplierPicker,
          ),
          const SizedBox(height: 8),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE4E7EC)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.add_box_outlined,
                  size: 18,
                  color: Color(0xFF657286),
                ),
                const SizedBox(width: 7),
                const Text(
                  'Jumlah Stok',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF30343B),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 95,
                  child: TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    onChanged: (_) {
                      if (isSaved) setState(() => isSaved = false);
                    },
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Contoh: 10',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB6BBC3),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  product?['unit']?.toString() ?? 'pcs',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF657286),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _dateField(),
          const SizedBox(height: 8),
          _noteField(),
          const SizedBox(height: 17),
          if (isSaved)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F8EE),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF38C878)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: Color(0xFF20B968),
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Stok masuk berhasil disimpan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF179957),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: isSaving || isLoading ? null : saveStockIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF9BAA98),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Simpan Stok Masuk',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorText(String message) {
    return Container(
      height: 28,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: _red),
          const SizedBox(width: 7),
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: _red),
          ),
        ],
      ),
    );
  }

  Widget _formRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 35,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E7EC)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF657286)),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF30343B),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: Color(0xFF788392),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: selectDate,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E7EC)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 35,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: Color(0xFF657286),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'Tanggal Transaksi',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF30343B),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.edit_calendar_outlined,
                      size: 18,
                      color: Color(0xFF657286),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F1F3)),
            SizedBox(
              height: 29,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  child: Text(
                    formatDate(selectedDate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF58606B),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteField() {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 29,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: Color(0xFF657286),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'Catatan',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF30343B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F1F3)),
          Expanded(
            child: TextField(
              controller: noteController,
              maxLines: 3,
              onChanged: (_) {
                if (isSaved) setState(() => isSaved = false);
              },
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Tulis catatan di sini...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB6BBC3),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      height: 82,
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomItem(Icons.home_outlined, 'Home', 0),
          _bottomItem(Icons.qr_code_scanner, 'Scanner', 1),
          _bottomItem(Icons.receipt_long_outlined, 'Riwayat', 2),
          _bottomItem(Icons.person_outline, 'Profil', 3),
        ],
      ),
    );
  }

  Widget _bottomItem(IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () => navigateBottom(index),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 27, color: const Color(0xFF718096)),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF718096),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
