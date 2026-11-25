
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState
    extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  final _green = const Color(0xFF5F7D5D);
  final _background = const Color(0xFFF4F5F8);

  bool _hideOld = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _isSaving = false;

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
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // =========================================================
  // UPDATE PASSWORD
  // =========================================================

  Future<void> _submit() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;

    if (_oldPassword.text == _newPassword.text) {
      _showMessage(
        'Kata sandi baru harus berbeda dari kata sandi lama.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token')?.trim();

      if (token == null || token.isEmpty) {
        if (!mounted) return;

        _showMessage(
          'Sesi login tidak ditemukan. Silakan login kembali.',
          isError: true,
        );
        return;
      }

      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/auth/change-password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'currentPassword': _oldPassword.text,
              'newPassword': _newPassword.text,
            }),
          )
          .timeout(const Duration(seconds: 15));

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final Map<String, dynamic> responseData =
          decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};

      if (response.statusCode == 200 &&
          responseData['success'] == true) {
        if (!mounted) return;

        _showMessage(
          responseData['message']?.toString() ??
              'Kata sandi berhasil diperbarui.',
        );

        _oldPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();

        await Future.delayed(
          const Duration(milliseconds: 700),
        );

        if (!mounted) return;

        Navigator.pop(context, true);
      } else {
        if (!mounted) return;

        _showMessage(
          responseData['message']?.toString() ??
              'Gagal memperbarui kata sandi '
                  '(${response.statusCode}).',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('CHANGE PASSWORD ERROR: $e');

      if (!mounted) return;

      _showMessage(
        'Tidak dapat menghubungi server. Periksa koneksi backend.',
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
        backgroundColor: isError ? Colors.red : _green,
      ),
    );
  }

  // =========================================================
  // INPUT DECORATION
  // =========================================================

  InputDecoration _decoration(
    String label,
    bool hidden,
    VoidCallback toggle,
  ) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: IconButton(
        onPressed: _isSaving ? null : toggle,
        icon: Icon(
          hidden ? Icons.visibility_off : Icons.visibility,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Ubah Kata Sandi'),
        backgroundColor: _background,
        foregroundColor: const Color(0xFF202124),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Perbarui keamanan akun Anda',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Gunakan kata sandi baru yang kuat dan tidak '
                'mudah ditebak.',
                style: TextStyle(color: Colors.black54),
              ),

              const SizedBox(height: 24),

              // PASSWORD LAMA

              TextFormField(
                controller: _oldPassword,
                obscureText: _hideOld,
                enabled: !_isSaving,
                decoration: _decoration(
                  'Kata sandi saat ini',
                  _hideOld,
                  () => setState(() => _hideOld = !_hideOld),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Masukkan kata sandi saat ini';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // PASSWORD BARU

              TextFormField(
                controller: _newPassword,
                obscureText: _hideNew,
                enabled: !_isSaving,
                decoration: _decoration(
                  'Kata sandi baru',
                  _hideNew,
                  () => setState(() => _hideNew = !_hideNew),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Masukkan kata sandi baru';
                  }

                  if (v.length < 8) {
                    return 'Minimal 8 karakter';
                  }

                  if (v.length > 72) {
                    return 'Maksimal 72 karakter';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // KONFIRMASI PASSWORD

              TextFormField(
                controller: _confirmPassword,
                obscureText: _hideConfirm,
                enabled: !_isSaving,
                decoration: _decoration(
                  'Konfirmasi kata sandi baru',
                  _hideConfirm,
                  () => setState(
                    () => _hideConfirm = !_hideConfirm,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Konfirmasi kata sandi baru';
                  }

                  if (v != _newPassword.text) {
                    return 'Konfirmasi kata sandi tidak cocok';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 28),

              // TOMBOL UPDATE

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        _green.withValues(alpha: 0.6),
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
                          'Perbarui Kata Sandi',
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
