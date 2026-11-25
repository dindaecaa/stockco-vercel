
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() =>
      _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _visible = false;
  bool _isLoading = false;

  static const green = Color(0xFF5F7457);
  static const background = Color(0xFFF4F5F8);

  static const String _accountsKey = 'stockco_saved_accounts';

  String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3001';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3001';
      default:
        return 'http://localhost:3001';
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // =========================================================
  // ADD ACCOUNT
  // =========================================================

  Future<void> _addAccount() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final email = _email.text.trim().toLowerCase();

      // Ambil akun yang sedang aktif.
      final currentUserData = prefs.getString('user_data');

      String? currentEmail;

      if (currentUserData != null) {
        try {
          final decoded = jsonDecode(currentUserData);

          if (decoded is Map) {
            currentEmail = decoded['email']
                ?.toString()
                .trim()
                .toLowerCase();
          }
        } catch (_) {
          // Lanjutkan proses login jika data lokal tidak terbaca.
        }
      }

      currentEmail ??= prefs.getString('profile_email')
          ?.trim()
          .toLowerCase();

      if (currentEmail == email) {
        _showMessage(
          'Akun ini sedang digunakan.',
          isError: true,
        );
        return;
      }

      // LOGIN KE BACKEND
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/auth/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'password': _password.text,
            }),
          )
          .timeout(const Duration(seconds: 15));

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final Map<String, dynamic> result =
          decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};

      if (response.statusCode != 200 ||
          result['success'] != true) {
        if (!mounted) return;

        _showMessage(
          result['message']?.toString() ??
              'Email atau kata sandi tidak sesuai.',
          isError: true,
        );
        return;
      }

      final token = result['token']?.toString();
      final user = result['data'];

      if (token == null ||
          token.isEmpty ||
          user is! Map) {
        if (!mounted) return;

        _showMessage(
          'Respons login dari server tidak lengkap.',
          isError: true,
        );
        return;
      }

      final accountData = Map<String, dynamic>.from(user);

      final accountEmail = accountData['email']
          ?.toString()
          .trim()
          .toLowerCase();

      if (accountEmail == null || accountEmail.isEmpty) {
        if (!mounted) return;

        _showMessage(
          'Data email akun tidak ditemukan.',
          isError: true,
        );
        return;
      }

      // AMBIL DAFTAR AKUN TAMBAHAN
      final savedAccountsRaw =
          prefs.getString(_accountsKey);

      List<Map<String, dynamic>> savedAccounts = [];

      if (savedAccountsRaw != null) {
        try {
          final decodedAccounts =
              jsonDecode(savedAccountsRaw);

          if (decodedAccounts is List) {
            savedAccounts = decodedAccounts
                .whereType<Map>()
                .map(
                  (item) => Map<String, dynamic>.from(item),
                )
                .toList();
          }
        } catch (_) {
          savedAccounts = [];
        }
      }

      // CEK DUPLIKAT
      final alreadyExists = savedAccounts.any(
        (account) =>
            account['email']
                ?.toString()
                .trim()
                .toLowerCase() ==
            accountEmail,
      );

      if (alreadyExists) {
        if (!mounted) return;

        _showMessage(
          'Akun tersebut sudah ditambahkan sebelumnya.',
          isError: true,
        );
        return;
      }

      // SIMPAN AKUN TAMBAHAN
      // Password tidak disimpan.
      savedAccounts.add({
        'id': accountData['id'],
        'name': accountData['name'],
        'email': accountEmail,
        'role': accountData['role'],
        'token': token,
      });

      await prefs.setString(
        _accountsKey,
        jsonEncode(savedAccounts),
      );

      if (!mounted) return;

      _showMessage(
        'Akun ${accountData['name'] ?? accountEmail} berhasil ditambahkan.',
      );

      _email.clear();
      _password.clear();

      await Future.delayed(
        const Duration(milliseconds: 600),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('ADD ACCOUNT ERROR: $e');

      if (!mounted) return;

      _showMessage(
        'Tidak dapat menghubungi server. '
        'Periksa koneksi backend.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : green,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(height: 14),

              const Text(
                'Tambah Akun',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Masuk ke akun lain tanpa keluar dari akun ini.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF737780),
                ),
              ),

              const SizedBox(height: 28),

              // FORM AKUN

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Color(0xFFEDF2EA),
                            child: Icon(
                              Icons.person_add_alt_1,
                              color: green,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Akun Stock.co lainnya',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Gunakan akun yang sudah terdaftar.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF737780),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Email',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _email,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: _decoration(
                          'Masukkan email akun',
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(email)) {
                            return 'Masukkan email yang valid';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Kata sandi',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _password,
                        enabled: !_isLoading,
                        obscureText: !_visible,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _addAccount(),
                        decoration: _decoration(
                          'Masukkan kata sandi',
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _visible = !_visible;
                                    });
                                  },
                            icon: Icon(
                              _visible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty
                                ? 'Kata sandi wajib diisi'
                                : null,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // BUTTON TAMBAH AKUN

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        green.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Tambah Akun',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // INFORMASI

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF2EA),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: green,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Akun yang sedang digunakan tetap tersimpan. '
                        'Akun tambahan dapat digunakan untuk '
                        'pengembangan fitur perpindahan akun.',
                        style: TextStyle(
                          color: green,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // INPUT DECORATION
  // =========================================================

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFAFAFB),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFFE3E5EA),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFFE3E5EA),
        ),
      ),
    );
  }
}
