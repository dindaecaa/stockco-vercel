
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_data.dart';

class EditProfileScreen extends StatefulWidget {
  final UserData user;

  const EditProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  static const Color green = Color(0xFF5F7D5D);
  static const Color background = Color(0xFFF4F5F8);

  static const String _userDataKey = 'user_data';
  static const String _tokenKey = 'token';
  static const String _nameKey = 'profile_name';
  static const String _emailKey = 'profile_email';

  bool _isSaving = false;

  // =========================================================
  // BASE URL
  // =========================================================

  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3001';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3001';

      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:3001';
    }
  }

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.user.name,
    );

    _emailController = TextEditingController(
      text: widget.user.email,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // =========================================================
  // SIMPAN DATA SESSION
  // =========================================================

  Future<void> _saveUserSession(UserData user) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _userDataKey,
      jsonEncode(user.toJson()),
    );

    await prefs.setString(
      _nameKey,
      user.name,
    );

    await prefs.setString(
      _emailKey,
      user.email,
    );

    final token = user.token?.trim();

    if (token != null && token.isNotEmpty) {
      await prefs.setString(
        _tokenKey,
        token,
      );
    }
  }

  // =========================================================
  // SIMPAN PERUBAHAN PROFIL KE MYSQL
  // =========================================================

  Future<void> _save() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final token = widget.user.token?.trim();

    if (token == null || token.isEmpty) {
      _showMessage(
        'Sesi login tidak ditemukan. Silakan login kembali.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/auth/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'name': name,
              'email': email,
            }),
          )
          .timeout(const Duration(seconds: 15));

      dynamic decodedBody;

      try {
        decodedBody = jsonDecode(response.body);
      } catch (_) {
        decodedBody = null;
      }

      final Map<String, dynamic> responseData =
          decodedBody is Map
              ? Map<String, dynamic>.from(decodedBody)
              : <String, dynamic>{};

      if (response.statusCode == 200 &&
          responseData['success'] == true) {
        final updatedData = responseData['data'];

        final Map<String, dynamic> userData =
            updatedData is Map
                ? Map<String, dynamic>.from(updatedData)
                : <String, dynamic>{};

        final updatedUser = widget.user.copyWith(
          id: int.tryParse(
                userData['id']?.toString() ?? '',
              ) ??
              widget.user.id,
          name: (userData['name'] ?? name).toString(),
          email: (userData['email'] ?? email).toString(),
          role: (userData['role'] ?? widget.user.role)
              .toString(),
          token: token,
        );

        // Perbarui objek pengguna aktif.
        widget.user.name = updatedUser.name;
        widget.user.email = updatedUser.email;
        widget.user.token = updatedUser.token;

        // Simpan data terbaru ke penyimpanan lokal.
        await _saveUserSession(updatedUser);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseData['message']?.toString() ??
                  'Profil berhasil diperbarui.',
            ),
            backgroundColor: green,
          ),
        );

        Navigator.pop(context, true);
      } else {
        final message =
            responseData['message']?.toString() ??
                'Gagal memperbarui profil. '
                    'Kode: ${response.statusCode}';

        if (!mounted) return;

        _showMessage(message, isError: true);
      }
    } catch (e) {
      debugPrint('UPDATE PROFILE ERROR: $e');

      if (!mounted) return;

      _showMessage(
        'Tidak dapat menghubungi server. '
        'Periksa koneksi backend dan jaringan.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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
  // INPUT DECORATION
  // =========================================================

  InputDecoration _decoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: green,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFE7E9ED),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: green,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
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
      appBar: AppBar(
        title: const Text(
          'Ubah Profil',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: background,
        foregroundColor: const Color(0xFF202124),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // FOTO PROFIL

                Center(
                  child: Container(
                    width: 94,
                    height: 94,
                    decoration: const BoxDecoration(
                      color: Color(0xFF667085),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                const Center(
                  child: Text(
                    'Edit informasi profil Anda',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A828D),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // NAMA LENGKAP

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    'Nama lengkap',
                    Icons.person_outline,
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Nama tidak boleh kosong';
                    }

                    if (value.trim().length < 2) {
                      return 'Nama minimal 2 karakter';
                    }

                    if (value.trim().length > 100) {
                      return 'Nama maksimal 100 karakter';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // EMAIL

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: _decoration(
                    'Email',
                    Icons.email_outlined,
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }

                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(email)) {
                      return 'Masukkan email yang valid';
                    }

                    if (email.length > 150) {
                      return 'Email maksimal 150 karakter';
                    }

                    return null;
                  },
                  onFieldSubmitted: (_) => _save(),
                ),

                const SizedBox(height: 28),

                // TOMBOL SIMPAN

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
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
                    child: _isSaving
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Simpan Perubahan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                // TOMBOL BATAL

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: green,
                      side: const BorderSide(
                        color: green,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
