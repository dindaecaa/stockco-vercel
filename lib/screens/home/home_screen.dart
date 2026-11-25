
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../models/user_data.dart';
import '../../widgets/ai_stock_notification.dart';

import '../scanner/scanner_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';

import '../inventory/stock_in_screen.dart';
import '../inventory/stock_out_screen.dart';
import '../inventory/data_barang_screen.dart';
import '../inventory/barang_rusak_screen.dart';
import '../inventory/category_custom_screen.dart';
import '../inventory/unit_custom_screen.dart';

import '../management/supplier_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserData? user;

  const HomeScreen({
    super.key,
    this.user,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color primaryGreen = Color(0xFF587B55);
  static const Color backgroundColor = Color(0xFFF4F5F8);

  // Mencegah notifikasi otomatis muncul berulang kali.
  bool _notificationChecked = false;
  bool _notificationDialogOpen = false;

  Map<String, int> _dashboardData = {};

  bool _isDashboardLoading = true;
  String? _dashboardError;

  int _dashboardValue(String key) {
    return _dashboardData[key] ?? 0;
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<String?> _getAuthToken() async {
    final userToken = widget.user?.token;

    if (userToken != null && userToken.trim().isNotEmpty) {
      return userToken.trim();
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token')?.trim();
  }

  Future<void> _fetchDashboard() async {
    if (!mounted) return;

    setState(() {
      _isDashboardLoading = true;
      _dashboardError = null;
    });

    try {
      final token = await _getAuthToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Sesi login tidak ditemukan. Silakan login kembali.',
        );
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/dashboard'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Server mengembalikan status ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic> ||
          decoded['success'] != true ||
          decoded['data'] is! Map) {
        throw Exception(
          'Format data dashboard dari server tidak sesuai.',
        );
      }

      final data = Map<String, dynamic>.from(
        decoded['data'] as Map,
      );

      if (!mounted) return;

      setState(() {
        _dashboardData = {
          'total_sku': _readInt(data['total_sku']),
          'total_stock': _readInt(data['total_stock']),
          'out_of_stock': _readInt(data['out_of_stock']),
          'low_stock': _readInt(data['low_stock']),
          'stock_in_30_days':
              _readInt(data['stock_in_30_days']),
          'stock_out_30_days':
              _readInt(data['stock_out_30_days']),
          'stock_in_previous_30_days':
              _readInt(data['stock_in_previous_30_days']),
          'stock_out_previous_30_days':
              _readInt(data['stock_out_previous_30_days']),
        };

        _isDashboardLoading = false;
        _dashboardError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isDashboardLoading = false;
        _dashboardError = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  String _comparisonLabel({
    required int current,
    required int previous,
  }) {
    final difference = current - previous;

    if (difference > 0) {
      return '+$difference vs sebelumnya';
    }

    if (difference < 0) {
      return '$difference vs sebelumnya';
    }

    return 'Sama vs sebelumnya';
  }

  String get displayName {
    final name = widget.user?.name.trim() ?? '';
    return name.isNotEmpty ? name : 'Pengguna';
  }

  String get displayRole {
    final role = widget.user?.role.trim() ?? '';

    if (role.isEmpty) return 'Staff';

    switch (role.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'leader':
        return 'Leader';
      case 'staff':
      case 'pegawai':
        return 'Staff';
      default:
        return role[0].toUpperCase() + role.substring(1);
    }
  }

  @override
  void initState() {
    super.initState();

    _fetchDashboard();

    // Pemeriksaan dan popup AI Stock otomatis setelah Home terbuka.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAutomaticNotification();
    });
  }

  // ==========================================
  // NOTIFIKASI AI STOCK OTOMATIS
  // ==========================================

  Future<void> _showAutomaticNotification() async {
    if (!mounted ||
        _notificationChecked ||
        _notificationDialogOpen) {
      return;
    }

    _notificationChecked = true;
    _notificationDialogOpen = true;

    try {
      final token = await _getAuthToken();

      if (!mounted) return;

      await AiStockNotification.show(
        context,
        token: token,
        showWhenEmpty: false,
        onFillStock: () {
          _openPage(StockInScreen());
        },
      );
    } finally {
      _notificationDialogOpen = false;
    }
  }

  // ==========================================
  // NOTIFIKASI AI STOCK MANUAL
  // ==========================================

  Future<void> _showManualNotification() async {
    if (!mounted || _notificationDialogOpen) return;

    _notificationDialogOpen = true;

    try {
      final token = await _getAuthToken();

      if (!mounted) return;

      await AiStockNotification.show(
        context,
        token: token,
        showWhenEmpty: true,
        onFillStock: () {
          _openPage(StockInScreen());
        },
      );
    } finally {
      _notificationDialogOpen = false;
    }
  }

  void _openPage(Widget page) {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _openScanner(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(),
      ),
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HistoryScreen(),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, displayName),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  16, 20, 16, 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWarehouseCard(),
                    const SizedBox(height: 20),
                    _buildTotalDataCard(),
                    const SizedBox(height: 20),
                    _buildDataBarang(context),
                    const SizedBox(height: 24),
                    const Text(
                      'Menu Cepat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF30343B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _menuCard(
                            icon: Icons.inventory_2_outlined,
                            title: 'Stok Masuk',
                            color: primaryGreen,
                            onTap: () => _openPage(
                              StockInScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _menuCard(
                            icon: Icons.outbox_outlined,
                            title: 'Stok Keluar',
                            color: const Color(0xFFE34F42),
                            onTap: () => _openPage(
                              StockOutScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _menuCard(
                            icon: Icons.warning_amber_rounded,
                            title: 'Barang Rusak',
                            color: const Color(0xFFD47735),
                            onTap: () => _openPage(
                              const BarangRusakScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _menuCard(
                            icon: Icons.category_outlined,
                            title: 'Kategori',
                            color: const Color(0xFF7540E8),
                            onTap: () => _openPage(
                              const CategoryCustomScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _menuCard(
                            icon: Icons.straighten_outlined,
                            title: 'Satuan',
                            color: const Color(0xFF3D62E8),
                            onTap: () => _openPage(
                              const UnitCustomScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _menuCard(
                            icon: Icons.local_shipping_outlined,
                            title: 'Pemasok',
                            color: const Color(0xFF54A7DF),
                            onTap: () => _openPage(
                              const SupplierScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildHeader(BuildContext context, String name) {
    return Container(
      height: 92,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white,
      child: Row(
        children: [
          InkWell(
            onTap: () => _openProfile(context),
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: primaryGreen,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _getInitials(name),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: InkWell(
              onTap: () => _openProfile(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202124),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notifikasi stok',
            onPressed: _showManualNotification,
            icon: const Icon(
              Icons.notifications_none_outlined,
              size: 28,
              color: Color(0xFF596579),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFD7E2FB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: Color(0xFF4168E8),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'stock.co',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF202124),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayRole,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF737D8F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalDataCard() {
    final stockIn = _dashboardValue('stock_in_30_days');
    final stockOut = _dashboardValue('stock_out_30_days');

    final previousStockIn =
        _dashboardValue('stock_in_previous_30_days');

    final previousStockOut =
        _dashboardValue('stock_out_previous_30_days');

    final stockInValue = _isDashboardLoading
        ? '...'
        : _dashboardError != null
            ? '-'
            : stockIn.toString();

    final stockOutValue = _isDashboardLoading
        ? '...'
        : _dashboardError != null
            ? '-'
            : stockOut.toString();

    final stockInSubtitle = _isDashboardLoading
        ? 'Memuat data...'
        : _dashboardError != null
            ? 'Gagal memuat data'
            : _comparisonLabel(
                current: stockIn,
                previous: previousStockIn,
              );

    final stockOutSubtitle = _isDashboardLoading
        ? 'Memuat data...'
        : _dashboardError != null
            ? 'Gagal memuat data'
            : _comparisonLabel(
                current: stockOut,
                previous: previousStockOut,
              );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Data',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF202124),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Color(0xFF718096),
                    ),
                    SizedBox(width: 7),
                    Text(
                      '30 Hari Terakhir',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _totalDataItem(
                  title: 'Stok Masuk',
                  value: stockInValue,
                  subtitle: stockInSubtitle,
                  icon: Icons.arrow_downward,
                  color: const Color(0xFF55B875),
                ),
              ),
              Container(
                width: 1,
                height: 92,
                color: const Color(0xFFE9ECF1),
              ),
              Expanded(
                child: _totalDataItem(
                  title: 'Stok Keluar',
                  value: stockOutValue,
                  subtitle: stockOutSubtitle,
                  icon: Icons.arrow_upward,
                  color: const Color(0xFFE34F42),
                ),
              ),
            ],
          ),
          if (_dashboardError != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Data dashboard belum bisa dimuat. Periksa koneksi backend.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD47735),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      _isDashboardLoading ? null : _fetchDashboard,
                  icon: const Icon(Icons.refresh, size: 17),
                  label: const Text('Coba lagi'),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _totalDataItem({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF737D8F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDataBarang(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _openPage(
          const DataBarangScreen(),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF1FF),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: primaryGreen,
                  size: 34,
                ),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Text(
                  'Data Barang',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF202124),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 30,
                color: Color(0xFF718096),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 150,
          padding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF30343B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomItem(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: true,
            onTap: () {},
          ),
          _bottomItem(
            icon: Icons.qr_code_scanner,
            label: 'Scanner',
            selected: false,
            onTap: () => _openScanner(context),
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
                    ? primaryGreen
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
                      ? primaryGreen
                      : const Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: selected ? 7 : 0,
                height: 5,
                decoration: const BoxDecoration(
                  color: primaryGreen,
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

  String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'P';

    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    final value = parts.first;

    if (value.length >= 2) {
      return value.substring(0, 2).toUpperCase();
    }

    return value[0].toUpperCase();
  }
}
