
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

class StockOutScreen extends StatefulWidget {
  final UserData user;

  StockOutScreen({
    super.key,
    UserData? user,
  }) : user = user ??
            UserData(
              name: 'Zefanya',
              email: '',
            );

  @override
  State<StockOutScreen> createState() => _StockOutScreenState();
}

class _StockOutScreenState extends State<StockOutScreen> {
  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';

  bool isLoading = true;
  String? errorMessage;

  List<StockOutTransaction> transactions = [];

  static const Color _green = Color(0xFF667A65);

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:3001';

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001';
    }

    return 'http://localhost:3001';
  }

 Future<Map<String, String>> getAuthHeaders() async {
  final prefs = await SharedPreferences.getInstance();
  final userToken = widget.user.token;

  final token = (userToken != null && userToken.isNotEmpty)
      ? userToken
      : prefs.getString('token');

  if (token == null || token.isEmpty) {
    throw Exception('Sesi login tidak ditemukan. Silakan login kembali.');
  }

  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/stock-movements'),
            headers: await getAuthHeaders(),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (response.statusCode != 200) {
        final message =
            decoded is Map ? decoded['message']?.toString() : null;

        throw Exception(
          message ?? 'Gagal mengambil transaksi (${response.statusCode}).',
        );
      }

      if (decoded is! Map ||
          decoded['success'] != true ||
          decoded['data'] is! List) {
        throw Exception('Format data transaksi tidak valid.');
      }

      final result = decoded['data'] as List;

      final loadedTransactions = result
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['type']?.toString() == 'out')
          .map(StockOutTransaction.fromJson)
          .toList();

      loadedTransactions.sort(
        (a, b) => b.dateTime.compareTo(a.dateTime),
      );

      if (!mounted) return;

      setState(() {
        transactions = loadedTransactions;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ==========================================
  // TAMBAH TRANSAKSI STOK KELUAR
  // ==========================================

  Future<List<Map<String, dynamic>>> loadProductsForStockOut() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/products'),
          headers: await getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200) {
      final message =
          decoded is Map ? decoded['message']?.toString() : null;
      throw Exception(message ?? 'Gagal mengambil data barang.');
    }

    if (decoded is! Map || decoded['success'] != true) {
      throw Exception('Format data barang tidak valid.');
    }

    final rawData = decoded['data'];

    if (rawData is! List) {
      throw Exception('Daftar barang tidak ditemukan.');
    }

    return rawData
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) {
          final stock = int.tryParse(item['stock']?.toString() ?? '') ?? 0;
          return stock > 0;
        })
        .toList();
  }

  Future<void> showCreateStockOut() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    List<Map<String, dynamic>> products;

    try {
      products = await loadProductsForStockOut();

      if (!mounted) return;

      if (products.isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Tidak ada barang dengan stok tersedia.'),
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (sheetContext) {
        return _StockOutFormSheet(
          products: products,
          baseUrl: baseUrl,
          getAuthHeaders: getAuthHeaders,
        );
      },
    );

    if (result == true && mounted) {
      await loadTransactions();

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Transaksi stok keluar berhasil ditambahkan.'),
          backgroundColor: _green,
        ),
      );
    }
  }

  List<StockOutTransaction> get filteredTransactions {
    if (searchQuery.trim().isEmpty) {
      return transactions;
    }

    final query = searchQuery.toLowerCase().trim();

    return transactions.where((transaction) {
      return transaction.product.toLowerCase().contains(query) ||
          transaction.customer.toLowerCase().contains(query) ||
          transaction.transactionCode.toLowerCase().contains(query) ||
          transaction.note.toLowerCase().contains(query);
    }).toList();
  }

  List<StockOutTransaction> get currentMonthTransactions {
    final now = DateTime.now();

    return transactions.where((transaction) {
      return transaction.dateTime.year == now.year &&
          transaction.dateTime.month == now.month;
    }).toList();
  }

  int get totalQuantityThisMonth {
    return currentMonthTransactions.fold(
      0,
      (total, item) => total + item.quantityValue,
    );
  }

  int get totalTransactionsThisMonth {
    return currentMonthTransactions.length;
  }

  String get currentMonthLabel {
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

    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  }

  void goScanner() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
  }

  void goHistory() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  void goProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen()),
    );
  }

  void showFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(18),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Stok Keluar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Tanggal'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Pelanggan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.error_outline),
                  title: const Text('Status'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void openTransactionDetail(StockOutTransaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Detail Transaksi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                _detailRow('Barang', transaction.product),
                _detailRow(
                  'Tanggal',
                  '${transaction.date}, ${transaction.time}',
                ),
                _detailRow('Pelanggan', transaction.customer),
                _detailRow('Jumlah', transaction.quantity),
                _detailRow('Kode', transaction.transactionCode),
                _detailRow(
                  'Catatan',
                  transaction.note.isEmpty ? '-' : transaction.note,
                ),
                const SizedBox(height: 10),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFE8F8EF),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: Color(0xFF20B968),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Transaksi Berhasil',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF20B968),
                          ),
                        ),
                      ],
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8A929E),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF30343B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = filteredTransactions;

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
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F4FF),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: Color(0xFF3576E8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Stok Keluar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: loadTransactions,
                    tooltip: 'Muat ulang',
                    icon: const Icon(Icons.refresh, color: _green),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _green),
                    )
                  : errorMessage != null
                      ? _errorState()
                      : RefreshIndicator(
                          color: _green,
                          onRefresh: loadTransactions,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              12,
                              16,
                              12,
                              20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _searchBar(),
                                const SizedBox(height: 14),
                                _summaryCard(),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Transaksi terbaru',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF30343B),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      currentMonthLabel,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF7D8590),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (data.isEmpty)
                                  _emptySearchState()
                                else
                                  ...data.map(_transactionCard),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showCreateStockOut,
        backgroundColor: _green,
        foregroundColor: Colors.white,
        tooltip: 'Tambah stok keluar',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat transaksi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF30343B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              errorMessage ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8A929E),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: loadTransactions,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE1E5EA)),
            ),
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() => searchQuery = value);
              },
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search,
                  size: 21,
                  color: Color(0xFF657286),
                ),
                hintText: 'Cari barang atau transaksi',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 50,
          height: 50,
          child: ElevatedButton(
            onPressed: showFilter,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF707C6E),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Icon(Icons.tune, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Barang keluar bulan ini',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$totalQuantityThisMonth',
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: Text(
                        'unit',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(
              minWidth: 78,
              minHeight: 58,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$totalTransactionsThisMonth',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'transaksi',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionCard(StockOutTransaction transaction) {
    return GestureDetector(
      onTap: () => openTransactionDetail(transaction),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 86),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 21,
                color: Color(0xFF687993),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${transaction.date} · ${transaction.time}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8A929E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.product,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF30343B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          transaction.customer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A929E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          transaction.transactionCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 62),
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                transaction.quantity,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF677181),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptySearchState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: const Column(
        children: [
          Icon(
            Icons.search_off,
            size: 40,
            color: Color(0xFFB5BBC4),
          ),
          SizedBox(height: 10),
          Text(
            'Transaksi tidak ditemukan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF555C66),
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Belum ada transaksi stok keluar.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9AA1AC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 82,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFECEEF1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _bottomItem(
              icon: Icons.home_outlined,
              label: 'Home',
              onTap: goHome,
            ),
          ),
          Expanded(
            child: _bottomItem(
              icon: Icons.qr_code_scanner,
              label: 'Scanner',
              onTap: goScanner,
            ),
          ),
          Expanded(
            child: _bottomItem(
              icon: Icons.receipt_long_outlined,
              label: 'Riwayat',
              onTap: goHistory,
            ),
          ),
          Expanded(
            child: _bottomItem(
              icon: Icons.person_outline,
              label: 'Profil',
              onTap: goProfile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    const Color itemColor = Color(0xFF718096);

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 27, color: itemColor),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// FORM STOK KELUAR
// ==========================================

class _StockOutFormSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final String baseUrl;
  final Future<Map<String, String>> Function() getAuthHeaders;

  const _StockOutFormSheet({
    required this.products,
    required this.baseUrl,
    required this.getAuthHeaders,
  });

  @override
  State<_StockOutFormSheet> createState() => _StockOutFormSheetState();
}

class _StockOutFormSheetState extends State<_StockOutFormSheet> {
  final quantityController = TextEditingController();
  final customerController = TextEditingController();
  final noteController = TextEditingController();

  int? selectedProductId;
  DateTime selectedDate = DateTime.now();
  bool isSubmitting = false;
  String? formError;

  Map<String, dynamic>? get selectedProduct {
    if (selectedProductId == null) return null;

    for (final product in widget.products) {
      final id = int.tryParse(product['id']?.toString() ?? '');
      if (id == selectedProductId) return product;
    }

    return null;
  }

  int get selectedStock {
    final product = selectedProduct;
    if (product == null) return 0;
    return int.tryParse(product['stock']?.toString() ?? '') ?? 0;
  }

  @override
  void dispose() {
    quantityController.dispose();
    customerController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      setState(() => selectedDate = picked);
    }
  }

  String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> submit() async {
    if (selectedProductId == null) {
      setState(() => formError = 'Silakan pilih barang terlebih dahulu.');
      return;
    }

    final quantity = int.tryParse(quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      setState(() => formError = 'Jumlah harus berupa angka lebih dari 0.');
      return;
    }

    if (quantity > selectedStock) {
      setState(() {
        formError = 'Jumlah melebihi stok tersedia ($selectedStock unit).';
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      formError = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('${widget.baseUrl}/api/stock-movements'),
            headers: await widget.getAuthHeaders(),
            body: jsonEncode({
              'product_id': selectedProductId,
              'supplier_id': null,
              'customer_name': customerController.text.trim().isEmpty
                  ? null
                  : customerController.text.trim(),
              'type': 'out',
              'quantity': quantity,
              'transaction_date': formatDate(selectedDate),
              'note': noteController.text.trim().isEmpty
                  ? null
                  : noteController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = jsonDecode(response.body);

      if (response.statusCode != 201 ||
          decoded is! Map ||
          decoded['success'] != true) {
        final message =
            decoded is Map ? decoded['message']?.toString() : null;
        throw Exception(
          message ?? 'Gagal menyimpan transaksi stok keluar.',
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        formError = e.toString().replaceFirst('Exception: ', '');
        isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tambah Stok Keluar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF30343B),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // PILIH BARANG
              const Text(
                'Barang',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: selectedProductId,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'Pilih barang',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                items: widget.products.map((product) {
                  final id = int.tryParse(product['id']?.toString() ?? '');
                  final name = product['name']?.toString() ?? 'Barang';
                  final stock =
                      int.tryParse(product['stock']?.toString() ?? '') ?? 0;

                 return DropdownMenuItem<int>(
                  value: id,
                  child: Text(
                  '$name (Stok: $stock)',
                  overflow: TextOverflow.ellipsis,
                   ),
                  );
                  }).toList(),
                 onChanged: isSubmitting
                     ? null
                  : (value) {
                  setState(() {
                  selectedProductId = value;
              });
               },
              ),
              if (selectedProduct != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F5F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Stok tersedia: $selectedStock unit',
                    style: const TextStyle(
                      color: _StockOutScreenState._green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // JUMLAH
              const Text(
                'Jumlah stok keluar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: quantityController,
                enabled: !isSubmitting,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Masukkan jumlah',
                  suffixText: 'unit',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // TANGGAL
              const Text(
                'Tanggal transaksi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: isSubmitting ? null : pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD5D9DF)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: _StockOutScreenState._green,
                      ),
                      const SizedBox(width: 10),
                      Text(formatDate(selectedDate)),
                      const Spacer(),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // PELANGGAN
              const Text(
                'Nama pelanggan (opsional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: customerController,
                enabled: !isSubmitting,
                decoration: InputDecoration(
                  hintText: 'Masukkan nama pelanggan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // CATATAN
              const Text(
                'Catatan (opsional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                enabled: !isSubmitting,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Tambahkan catatan transaksi',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              if (formError != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    formError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _StockOutScreenState._green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan Transaksi',
                          style: TextStyle(
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
}

class StockOutTransaction {
  final int id;
  final String date;
  final String time;
  final DateTime dateTime;
  final String product;
  final String customer;
  final String transactionCode;
  final String quantity;
  final int quantityValue;
  final String note;

  StockOutTransaction({
    required this.id,
    required this.date,
    required this.time,
    required this.dateTime,
    required this.product,
    required this.customer,
    required this.transactionCode,
    required this.quantity,
    required this.quantityValue,
    required this.note,
  });

  factory StockOutTransaction.fromJson(Map<String, dynamic> json) {
    final rawDate = json['transaction_date']?.toString();
    final rawCreatedAt = json['created_at']?.toString();

    DateTime? parsedCreatedAt;
    DateTime? parsedTransactionDate;

    if (rawCreatedAt != null && rawCreatedAt.isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    }

    if (rawDate != null && rawDate.isNotEmpty) {
      parsedTransactionDate = DateTime.tryParse(rawDate);
    }

    final parsedDate =
        parsedTransactionDate ?? parsedCreatedAt ?? DateTime.now();

    final displayDate = parsedDate.toLocal();
    final displayTime = (parsedCreatedAt ?? parsedDate).toLocal();

    final id = int.tryParse(json['id']?.toString() ?? '') ?? 0;
    final quantityValue =
        int.tryParse(json['quantity']?.toString() ?? '') ?? 0;

    final customerName = json['customer_name']?.toString().trim() ?? '';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final date =
        '${displayDate.day} ${months[displayDate.month - 1]} ${displayDate.year}';

    final time =
        '${displayTime.hour.toString().padLeft(2, '0')}:'
        '${displayTime.minute.toString().padLeft(2, '0')}';

    final codeDate =
        '${displayDate.year.toString().substring(2)}'
        '${displayDate.month.toString().padLeft(2, '0')}'
        '${displayDate.day.toString().padLeft(2, '0')}';

    final code = '#SK-$codeDate-${id.toString().padLeft(3, '0')}';

    return StockOutTransaction(
      id: id,
      date: date,
      time: time,
      dateTime: displayDate,
      product: json['product_name']?.toString() ?? 'Barang',
      customer: customerName.isEmpty ? '-' : customerName,
      transactionCode: code,
      quantity: '-$quantityValue unit',
      quantityValue: quantityValue,
      note: json['note']?.toString() ?? '',
    );
  }
}
