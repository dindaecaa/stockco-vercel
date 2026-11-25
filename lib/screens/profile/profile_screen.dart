
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'add_account_screen.dart';
import 'branches_screen.dart';

import '../home/home_screen.dart';
import '../scanner/scanner_screen.dart';
import '../history/history_screen.dart';

import '../../models/user_data.dart';

import 'team_members_screen.dart';
import 'help_center_screen.dart';
import 'feedback_screen.dart';

import '../onboarding/welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserData? user;

  const ProfileScreen({
    super.key,
    this.user,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool notificationEnabled = true;
  bool biometricEnabled = true;

  String? _localName;
  String? _localEmail;

  UserData? _currentUser;

  static const String _nameKey = 'profile_name';
  static const String _emailKey = 'profile_email';
  static const String _userDataKey = 'user_data';
  static const String _tokenKey = 'token';

  static const String _notificationKey =
      'stockco_notification_enabled';

  static const String _biometricKey =
      'stockco_biometric_enabled';

  @override
  void initState() {
    super.initState();

    _currentUser = widget.user;
    _loadProfileData();
  }

  // =========================================================
  // HELPER
  // =========================================================

  String? _getValidValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return value.trim();
  }

  // =========================================================
  // LOAD PROFILE DATA
  // =========================================================

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      UserData? savedUser;

      final savedUserJson = prefs.getString(_userDataKey);

      if (savedUserJson != null && savedUserJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(savedUserJson);

          if (decoded is Map) {
            savedUser = UserData.fromJson(
              Map<String, dynamic>.from(decoded),
            );
          }
        } catch (e) {
          debugPrint('LOAD SAVED USER ERROR: $e');
        }
      }

      // Prioritaskan user aktif, kemudian data tersimpan.
      final sourceUser = widget.user ?? savedUser;

      UserData? restoredUser;

      if (sourceUser != null) {
        final savedToken = _getValidValue(
          prefs.getString(_tokenKey),
        );

        final currentToken = _getValidValue(
          sourceUser.token,
        );

        restoredUser = UserData.fromJson({
          ...sourceUser.toJson(),
          'token': currentToken ?? savedToken,
        });
      }

      // Ambil data terbaru dari SharedPreferences.
      final savedName = _getValidValue(
        prefs.getString(_nameKey),
      );

      final savedEmail = _getValidValue(
        prefs.getString(_emailKey),
      );

      // Prioritas nama dan email:
      // 1. SharedPreferences terbaru.
      // 2. User dari halaman sebelumnya.
      // 3. Data user yang berhasil dipulihkan.
      final restoredName = savedName ??
          _getValidValue(widget.user?.name) ??
          _getValidValue(restoredUser?.name);

      final restoredEmail = savedEmail ??
          _getValidValue(widget.user?.email) ??
          _getValidValue(restoredUser?.email);

      // Sinkronkan nama dan email ke objek pengguna.
      if (restoredUser != null) {
        restoredUser = restoredUser.copyWith(
          name: restoredName ?? restoredUser.name,
          email: restoredEmail ?? restoredUser.email,
        );
      }

      if (!mounted) return;

      setState(() {
        _currentUser = restoredUser;

        _localName = restoredName;
        _localEmail = restoredEmail;

        notificationEnabled =
            prefs.getBool(_notificationKey) ?? true;

        biometricEnabled =
            prefs.getBool(_biometricKey) ?? true;
      });

      // Simpan kembali data sesi yang sudah dipulihkan.
      if (restoredUser != null) {
        await _saveUserSession(restoredUser);
      }
    } catch (e) {
      debugPrint('LOAD PROFILE ERROR: $e');
    }
  }

  // =========================================================
  // SAVE USER SESSION
  // =========================================================

  Future<void> _saveUserSession(UserData user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _userDataKey,
        jsonEncode(user.toJson()),
      );

      final token = _getValidValue(user.token);

      if (token != null) {
        await prefs.setString(
          _tokenKey,
          token,
        );
      }

      await prefs.setString(
        _nameKey,
        user.name,
      );

      await prefs.setString(
        _emailKey,
        user.email,
      );
    } catch (e) {
      debugPrint('SAVE USER SESSION ERROR: $e');
    }
  }

  // =========================================================
  // PROFILE INFORMATION
  // =========================================================

  UserData? get activeUser {
    return _currentUser ?? widget.user;
  }

  String get userName {
    final name = _getValidValue(_localName) ??
        _getValidValue(activeUser?.name);

    return name ?? 'Pengguna';
  }

  String get userEmail {
    final email = _getValidValue(_localEmail) ??
        _getValidValue(activeUser?.email);

    return email ?? 'Belum ada email';
  }

  String get userInitials {
    final name = userName.trim();

    if (name.isEmpty || name == 'Pengguna') {
      return 'P';
    }

    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    return parts[0][0].toUpperCase();
  }

  // =========================================================
  // PREFERENCES
  // =========================================================

  Future<void> _saveNotificationSetting(bool value) async {
    setState(() {
      notificationEnabled = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        _notificationKey,
        value,
      );
    } catch (e) {
      debugPrint('SAVE NOTIFICATION ERROR: $e');
    }
  }

  Future<void> _saveBiometricSetting(bool value) async {
    setState(() {
      biometricEnabled = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        _biometricKey,
        value,
      );
    } catch (e) {
      debugPrint('SAVE BIOMETRIC ERROR: $e');
    }
  }

  // =========================================================
  // NAVIGATION
  // =========================================================

  void goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          user: activeUser,
        ),
      ),
    );
  }

  void goScanner() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(),
      ),
    );
  }

  void goHistory() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HistoryScreen(),
      ),
    );
  }

  // =========================================================
  // EDIT PROFILE
  // =========================================================

  Future<void> _openEditProfile() async {
    final editableUser = activeUser;

    if (editableUser == null) {
      _showMessage(
        'Data pengguna tidak ditemukan. Silakan login kembali.',
      );
      return;
    }

    if (!editableUser.hasToken) {
      _showMessage(
        'Sesi login tidak ditemukan. Silakan login kembali.',
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          user: editableUser,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _loadProfileData();

      if (!mounted) return;

      _showMessage('Profil berhasil diperbarui.');
    }
  }

  // =========================================================
  // OTHER ACCOUNT MENUS
  // =========================================================

  Future<void> _openChangePassword() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChangePasswordScreen(),
      ),
    );
  }

  Future<void> _openAddAccount() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddAccountScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      _showMessage('Akun berhasil ditambahkan.');
    }
  }

  Future<void> _openBranches() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BranchesScreen(),
      ),
    );
  }

  Future<void> _openTeam() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeamMembersScreen(),
      ),
    );
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text(
            'Apakah kamu yakin ingin keluar dari akun?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF587B55),
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (result != true || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Hapus data autentikasi dan profil.
      await prefs.remove(_userDataKey);
      await prefs.remove(_tokenKey);
      await prefs.remove(_nameKey);
      await prefs.remove(_emailKey);

    } catch (e) {
      debugPrint('LOGOUT ERROR: $e');

      if (!mounted) return;

      _showMessage('Gagal menghapus sesi login.');
      return;
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const WelcomeScreen(),
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
      backgroundColor: const Color(0xFFF4F5F8),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  4,
                  12,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Profil',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF202124),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 13),

                    _profileCard(),

                    const SizedBox(height: 10),

                    _sectionTitle('AKUN'),
                    const SizedBox(height: 5),

                    _menuContainer(
                      children: [
                        _menuItem(
                          icon: Icons.person_outline,
                          iconBackground:
                              const Color(0xFFF0F2F5),
                          title: 'Ubah Profil',
                          subtitle:
                              'Edit nama, email, dan foto profil',
                          onTap: _openEditProfile,
                        ),
                        _divider(),
                        _menuItem(
                          icon: Icons.lock_outline,
                          iconBackground:
                              const Color(0xFFF0F2F5),
                          title: 'Ubah Kata Sandi',
                          subtitle:
                              'Perbarui keamanan akun Anda',
                          onTap: _openChangePassword,
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          onPressed: _openAddAccount,
                          icon: const Icon(
                            Icons.add,
                            size: 18,
                          ),
                          label: const Text(
                            'Tambah',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF5F7D5D),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    _sectionTitle('BISNIS & TIM'),
                    const SizedBox(height: 5),

                    _menuContainer(
                      children: [
                        _menuItem(
                          icon: Icons.store_outlined,
                          iconBackground:
                              const Color(0xFFE9F0FF),
                          title: 'Kelola Cabang',
                          subtitle:
                              'Tambah, edit, atau hapus cabang',
                          onTap: _openBranches,
                        ),
                        _divider(),
                        _menuItem(
                          icon: Icons.people_outline,
                          iconBackground:
                              const Color(0xFFE9F0FF),
                          title: 'Anggota Tim',
                          subtitle:
                              'Atur anggota dan hak akses',
                          onTap: _openTeam,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _sectionTitle('PREFERENSI'),
                    const SizedBox(height: 5),

                    _menuContainer(
                      children: [
                        _switchMenuItem(
                          icon: Icons.notifications_none,
                          title: 'Notifikasi',
                          subtitle:
                              'Pemberitahuan stok dan aktivitas',
                          value: notificationEnabled,
                          onChanged: _saveNotificationSetting,
                        ),
                        _divider(),
                        _switchMenuItem(
                          icon: Icons.fingerprint,
                          title: 'Otentikasi Biometrik',
                          subtitle:
                              'Masuk dengan sidik jari atau wajah',
                          value: biometricEnabled,
                          onChanged: _saveBiometricSetting,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _sectionTitle('DUKUNGAN'),
                    const SizedBox(height: 5),

                    _menuContainer(
                      children: [
                        _menuItem(
                          icon: Icons.lightbulb_outline,
                          iconBackground:
                              const Color(0xFFFFF1E5),
                          title: 'Kirim Kritik dan Saran',
                          subtitle:
                              'Bantu kami meningkatkan aplikasi',
                          onTap: () async {
                            final sent =
                                await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const FeedbackScreen(),
                              ),
                            );

                            if (sent == true && mounted) {
                              _showMessage(
                                'Masukan berhasil dikirim.',
                              );
                            }
                          },
                        ),
                        _divider(),
                        _menuItem(
                          icon: Icons.help_outline,
                          iconBackground:
                              const Color(0xFFF0F2F5),
                          title: 'Pusat Bantuan',
                          subtitle:
                              'Panduan dan dukungan penggunaan',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const HelpCenterScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _sectionTitle('LOGOUT'),
                    const SizedBox(height: 5),

                    _menuContainer(
                      children: [
                        _menuItem(
                          icon: Icons.logout,
                          iconBackground:
                              const Color(0xFFFFEDE5),
                          title: 'Logout',
                          subtitle:
                              'Keluar dari akun Stock.co',
                          onTap: _confirmLogout,
                        ),
                      ],
                    ),

                    const SizedBox(height: 13),

                    const Center(
                      child: Text(
                        'Stock.co v2.4.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9AA1AC),
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

  // =========================================================
  // PROFILE CARD
  // =========================================================

  Widget _profileCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openEditProfile,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF667085),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      userInitials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF30343B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9AA1AC),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 21,
                  color: Color(0xFF7B8490),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF7A828D),
      ),
    );
  }

  // =========================================================
  // MENU CONTAINER
  // =========================================================

  Widget _menuContainer({
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(children: children),
    );
  }

  // =========================================================
  // MENU ITEM
  // =========================================================

  Widget _menuItem({
    required IconData icon,
    required Color iconBackground,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? trailingText,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        height: 78,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3D4249),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9AA1AC),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8B93A1),
                  ),
                ),
              if (showChevron) const SizedBox(width: 5),
              if (showChevron)
                const Icon(
                  Icons.chevron_right,
                  size: 21,
                  color: Color(0xFF8B93A1),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SWITCH MENU ITEM
  // =========================================================

  Widget _switchMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      height: 78,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                size: 21,
                color: const Color(0xFF667085),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3D4249),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9AA1AC),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF20C769),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFD4D8DD),
              materialTapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DIVIDER
  // =========================================================

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.only(left: 40),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: Color(0xFFF0F1F3),
      ),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

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
          _bottomItem(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: false,
            onTap: goHome,
          ),
          _bottomItem(
            icon: Icons.qr_code_scanner,
            label: 'Scanner',
            selected: false,
            onTap: goScanner,
          ),
          _bottomItem(
            icon: Icons.receipt_long_outlined,
            label: 'Riwayat',
            selected: false,
            onTap: goHistory,
          ),
          _bottomItem(
            icon: Icons.person_outline,
            label: 'Profil',
            selected: true,
            onTap: () {},
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
                    ? const Color(0xFF587B55)
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
                      ? const Color(0xFF587B55)
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

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}
