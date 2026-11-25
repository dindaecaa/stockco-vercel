
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import 'login_screen.dart';

class NewPasswordScreen extends StatefulWidget {
  final String resetToken;

  const NewPasswordScreen({
    super.key,
    required this.resetToken,
  });

  @override
  State<NewPasswordScreen> createState() =>
      _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // ================================================
  // RESET PASSWORD
  // ================================================

  Future<void> resetPassword() async {
    if (isLoading) return;

    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    String? errorMessage;

    if (password.isEmpty || confirmPassword.isEmpty) {
      errorMessage = 'Semua kolom password wajib diisi.';
    } else if (password.length < 8) {
      errorMessage = 'Password minimal 8 karakter.';
    } else if (password.length > 72) {
      errorMessage = 'Password maksimal 72 karakter.';
    } else if (password != confirmPassword) {
      errorMessage = 'Konfirmasi password tidak sama.';
    }

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/auth/reset-password',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'resetToken': widget.resetToken,
              'newPassword': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Respons server tidak valid.');
      }

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decoded['message'] ??
                  'Password berhasil diperbarui.',
            ),
            backgroundColor: const Color(0xFF587B55),
          ),
        );

        await Future.delayed(
          const Duration(milliseconds: 500),
        );

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decoded['message']?.toString() ??
                  'Gagal mengubah password.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      debugPrint('Reset password error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tidak dapat menghubungi server. Detail: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ================================================
  // BUILD
  // ================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LOGO

                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D2A20),
                                borderRadius:
                                    BorderRadius.circular(3),
                              ),
                              child: const Icon(
                                Icons.view_in_ar,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'stock.co',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 42),

                      // TITLE

                      const Text(
                        'New Password',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Please create a new password for your account.\n'
                        'Your password must contain at least 8 characters.',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.45,
                          color: Color(0xFF444444),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // PASSWORD LABEL

                      const Text(
                        'New Password',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222222),
                        ),
                      ),

                      const SizedBox(height: 7),

                      // PASSWORD INPUT

                      _passwordField(
                        controller: passwordController,
                        hintText: 'Enter new password',
                        obscureText: obscurePassword,
                        onToggle: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      // CONFIRM PASSWORD LABEL

                      const Text(
                        'Confirm Password',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222222),
                        ),
                      ),

                      const SizedBox(height: 7),

                      // CONFIRM PASSWORD INPUT

                      _passwordField(
                        controller: confirmPasswordController,
                        hintText: 'Confirm new password',
                        obscureText: obscureConfirmPassword,
                        onToggle: () {
                          setState(() {
                            obscureConfirmPassword =
                                !obscureConfirmPassword;
                          });
                        },
                      ),

                      const SizedBox(height: 40),

                      // RESET BUTTON

                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed:
                              isLoading ? null : resetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF5F7D5D),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFF5F7D5D),
                            disabledForegroundColor:
                                Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(22),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Reset Password',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ================================================
  // PASSWORD FIELD
  // ================================================

  Widget _passwordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: !isLoading,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF333333),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 12,
          color: Color(0xFFAAAAAA),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 18,
            color: Colors.grey,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(
            color: Colors.black,
            width: 1.1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(
            color: Colors.black,
            width: 1.1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(
            color: Color(0xFF5F7D5D),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
