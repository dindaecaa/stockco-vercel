
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../models/user_data.dart';
import '../home/home_screen.dart';
import '../scanner/scanner_screen.dart';
import '../profile/profile_screen.dart';
import 'receipt_preview_screen.dart';

class HistoryScreen extends StatefulWidget {
  final UserData? user;

  const HistoryScreen({
    super.key,
    this.user,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int selectedTab = 0;

  List<HistoryItem> historyData = [];

  bool isLoading = true;
  String? errorMessage;

  String searchQuery = '';
  String selectedDateFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ==========================================
  // MENGAMBIL TOKEN LOGIN
  // ==========================================

  Future<String?> _getToken() async {
    final userToken = widget.user?.token;

    if (userToken != null && userToken.isNotEmpty) {
      return userToken;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ==========================================
  // MENGAMBIL DATA RIWAYAT DARI BACKEND
  // ==========================================

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Sesi login tidak ditemukan. Silakan login kembali.',
        );
      }

      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/stock-movements',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 ||
          response.statusCode == 403) {
        throw Exception(
          'Sesi login tidak valid atau telah berakhir. '
          'Silakan login kembali.',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Gagal mengambil riwayat. '
          'Kode server: ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception('Format respons server tidak valid.');
      }

      if (decoded['success'] != true) {
        throw Exception(
          decoded['message']?.toString() ??
              'Gagal mengambil data riwayat.',
        );
      }

      final rawData = decoded['data'];

      if (rawData is! List) {
        throw Exception('Data riwayat tidak berbentuk daftar.');
      }

      final loadedData = rawData
          .whereType<Map>()
          .map(
            (item) => HistoryItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        historyData = loadedData;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = error.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
    }
  }

  // ==========================================
  // FILTER DATA RIWAYAT
  // ==========================================

  List<HistoryItem> get filteredHistory {
    final now = DateTime.now();

    return historyData.where((item) {
      if (selectedTab == 1 &&
          item.type != HistoryType.inbound) {
        return false;
      }

      if (selectedTab == 2 &&
          item.type != HistoryType.outbound) {
        return false;
      }

      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();

        final matchesSearch =
            item.name.toLowerCase().contains(query) ||
            item.sku.toLowerCase().contains(query) ||
            (item.note?.toLowerCase().contains(query) ?? false);

        if (!matchesSearch) return false;
      }

      if (selectedDateFilter != 'Semua') {
        if (item.createdAt == null) return false;

        final difference = now.difference(item.createdAt!);

        if (selectedDateFilter == '7 Hari Terakhir') {
          if (difference.isNegative ||
              difference.inDays >= 7) {
            return false;
          }
        }

        if (selectedDateFilter == '30 Hari Terakhir') {
          if (difference.isNegative ||
              difference.inDays >= 30) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  // ==========================================
  // DETAIL STRUK
  // ==========================================

  void _openReceipt(HistoryItem item) {
    final prefix = item.type == HistoryType.inbound
        ? 'SM'
        : 'SK';

    final transactionNumber =
        '#$prefix-${item.id.toString().padLeft(6, '0')}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptPreviewScreen(
          transactionNumber: transactionNumber,
          date: item.date,
          type: item.type == HistoryType.inbound
              ? 'Stok Masuk'
              : 'Stok Keluar',
          productName: item.name,
          sku: item.sku,
          quantity: item.quantity,
          status: item.status,
        ),
      ),
    );
  }

  // ==========================================
  // SEARCH
  // ==========================================

  void _showSearchDialog() {
    final controller = TextEditingController(
      text: searchQuery,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cari Riwayat'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nama barang atau SKU',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (value) {
              setState(() {
                searchQuery = value.trim();
              });

              Navigator.pop(dialogContext);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  searchQuery = '';
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('Reset'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  searchQuery = controller.text.trim();
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('Cari'),
            ),
          ],
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  // ==========================================
  // FILTER TANGGAL
  // ==========================================

  void _showFilterDialog() {
    const filters = [
      'Semua',
      '7 Hari Terakhir',
      '30 Hari Terakhir',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Riwayat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Periode Tanggal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                RadioGroup<String>(
                  groupValue: selectedDateFilter,
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      selectedDateFilter = value;
                    });

                    Navigator.pop(sheetContext);
                  },
                  child: Column(
                    children: filters.map((filter) {
                      return RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          filter,
                          style: const TextStyle(
                            fontSize: 13,
                          ),
                        ),
                        value: filter,
                        activeColor: const Color(0xFF587B55),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // NAVIGASI BOTTOM
  // ==========================================

  void _onBottomNavigationTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            user: widget.user,
          ),
        ),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ScannerScreen(
            user: widget.user,
          ),
        ),
      );
    } else if (index == 2) {
      return;
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
            user: widget.user,
          ),
        ),
      );
    }
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final data = filteredHistory;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(
                14,
                10,
                14,
                9,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Riwayat',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202124),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _showSearchDialog,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 38,
                      minHeight: 32,
                    ),
                    icon: const Icon(
                      Icons.search,
                      size: 21,
                      color: Color(0xFF4F5573),
                    ),
                  ),
                  IconButton(
                    onPressed: _showFilterDialog,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 38,
                      minHeight: 32,
                    ),
                    icon: const Icon(
                      Icons.filter_alt_outlined,
                      size: 20,
                      color: Color(0xFF4F5573),
                    ),
                  ),
                  IconButton(
                    onPressed: _loadHistory,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: const Icon(
                      Icons.refresh,
                      size: 20,
                      color: Color(0xFF4F5573),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF587B55),
                      ),
                    )
                  : errorMessage != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _loadHistory,
                          color: const Color(0xFF587B55),
                          child: SingleChildScrollView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 10,
                            ),
                            child: Column(
                              children: [
                                _buildTabBar(),
                                const SizedBox(height: 10),
                                if (data.isEmpty)
                                  _buildEmptyState()
                                else
                                  _buildHistoryList(data),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // ==========================================
  // ERROR STATE
  // ==========================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 55,
              color: Color(0xFF9AA1AC),
            ),
            const SizedBox(height: 12),
            const Text(
              'Gagal Memuat Riwayat',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8B93A1),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF587B55),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB BAR
  // ==========================================

  Widget _buildTabBar() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _tabItem(title: 'Semua', index: 0),
          _tabItem(title: 'Stok Masuk', index: 1),
          _tabItem(title: 'Stok Keluar', index: 2),
        ],
      ),
    );
  }

  Widget _tabItem({
    required String title,
    required int index,
  }) {
    final isSelected = selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              right: index != 2
                  ? const BorderSide(
                      color: Color(0xFFF0F0F0),
                    )
                  : BorderSide.none,
              bottom: isSelected
                  ? const BorderSide(
                      color: Color(0xFF2388E8),
                      width: 2,
                    )
                  : BorderSide.none,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight:
                  isSelected ? FontWeight.w500 : FontWeight.w400,
              color: isSelected
                  ? const Color(0xFF2388E8)
                  : const Color(0xFF687080),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // LIST RIWAYAT
  // ==========================================

  Widget _buildHistoryList(List<HistoryItem> data) {
    return Column(
      children: data.map(_historyCard).toList(),
    );
  }

  Widget _historyCard(HistoryItem item) {
    final isInbound = item.type == HistoryType.inbound;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openReceipt(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: isInbound
                        ? const Color(0xFFD9F8E8)
                        : const Color(0xFFFFE4E5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isInbound
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 15,
                    color: isInbound
                        ? const Color(0xFF18C77A)
                        : const Color(0xFFFF5964),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF30343B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.sku} · ${item.quantity}',
                        style: const TextStyle(
                          fontSize: 8,
                          color: Color(0xFF8B93A1),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.note?.isNotEmpty == true
                            ? item.note!
                            : 'Ketuk untuk melihat struk',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 7,
                          color: Color(0xFF9AA1AC),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.date,
                      style: const TextStyle(
                        fontSize: 8,
                        color: Color(0xFF9AA1AC),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isInbound
                            ? const Color(0xFFD9F8E8)
                            : const Color(0xFFFFD9DB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.status,
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w500,
                          color: isInbound
                              ? const Color(0xFF18A96B)
                              : const Color(0xFFFF5964),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.chevron_right,
                  size: 17,
                  color: Color(0xFF9AA1AC),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // EMPTY STATE
  // ==========================================

  Widget _buildEmptyState() {
    final hasFilter =
        searchQuery.isNotEmpty ||
        selectedDateFilter != 'Semua' ||
        selectedTab != 0;

    return SizedBox(
      height: 420,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFFE1EBF9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_outlined,
                size: 43,
                color: Color(0xFF3974D9),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasFilter
                  ? 'Riwayat Tidak Ditemukan'
                  : 'Tidak Ada Riwayat',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              hasFilter
                  ? 'Coba ubah pencarian atau filter.'
                  : 'Belum ada transaksi stok yang tercatat.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                height: 1.5,
                color: Color(0xFF9AA1AC),
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    searchQuery = '';
                    selectedDateFilter = 'Semua';
                    selectedTab = 0;
                  });
                },
                child: const Text('Hapus Filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION
  // ==========================================

  Widget _buildBottomNavigation() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      height: 82,
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
              selected: false,
              onTap: () => _onBottomNavigationTapped(0),
            ),
          ),
          Expanded(
            child: _bottomItem(
              icon: Icons.qr_code_scanner_outlined,
              label: 'Scan',
              selected: false,
              onTap: () => _onBottomNavigationTapped(1),
            ),
          ),
          Expanded(
            child: _bottomItem(
              icon: Icons.history,
              label: 'Riwayat',
              selected: true,
              onTap: () => _onBottomNavigationTapped(2),
            ),
          ),
          Expanded(
            child: _bottomItem(
              icon: Icons.person_outline,
              label: 'Profil',
              selected: false,
              onTap: () => _onBottomNavigationTapped(3),
            ),
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
    const activeColor = Color(0xFF587B55);
    const inactiveColor = Color(0xFF718096);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 27,
              color: selected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MODEL HISTORY
// ==========================================

class HistoryItem {
  final int id;
  final String name;
  final String sku;
  final String quantity;
  final String date;
  final DateTime? createdAt;
  final HistoryType type;
  final String status;
  final String? note;

  const HistoryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.quantity,
    required this.date,
    required this.createdAt,
    required this.type,
    required this.status,
    this.note,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString().toLowerCase();

    final isInbound = rawType == 'in';

    final rawDate = json['created_at']?.toString();

    final parsedDate = rawDate == null
        ? null
        : DateTime.tryParse(rawDate);

    final rawQuantity = json['quantity'];

    final quantityValue = rawQuantity is num
        ? rawQuantity
        : num.tryParse(rawQuantity?.toString() ?? '') ?? 0;

    return HistoryItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['product_name']?.toString() ??
          'Barang tidak diketahui',
      sku: json['product_sku']?.toString() ?? '-',
      quantity: '${quantityValue.toStringAsFixed(
        quantityValue % 1 == 0 ? 0 : 2,
      )} unit',
      date: _formatDateValue(parsedDate),
      createdAt: parsedDate,
      type: isInbound
          ? HistoryType.inbound
          : HistoryType.outbound,
      status: isInbound ? 'Diterima' : 'Dikeluarkan',
      note: json['note']?.toString(),
    );
  }

  static String _formatDateValue(DateTime? date) {
    if (date == null) return '-';

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

    final localDate = date.toLocal();
    final now = DateTime.now();

    final time =
        '${localDate.hour.toString().padLeft(2, '0')}:'
        '${localDate.minute.toString().padLeft(2, '0')}';

    if (localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day) {
      return 'Hari ini, $time';
    }

    final yesterday = now.subtract(const Duration(days: 1));

    if (localDate.year == yesterday.year &&
        localDate.month == yesterday.month &&
        localDate.day == yesterday.day) {
      return 'Kemarin, $time';
    }

    return '${localDate.day} '
        '${months[localDate.month - 1]}, $time';
  }
}

enum HistoryType {
  inbound,
  outbound,
}
