
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../models/user_data.dart';
import 'signup_screen.dart';
import '../home/home_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIN
  // ==========================================

  Future<void> login() async {
    if (isLoading) return;

    final email = emailController.text.trim();
    final password = passwordController.text;

    final emailPattern =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    String? errorMessage;

    if (email.isEmpty) {
      errorMessage = 'Email wajib diisi.';
    } else if (!emailPattern.hasMatch(email)) {
      errorMessage = 'Masukkan alamat email yang valid.';
    } else if (password.isEmpty) {
      errorMessage = 'Password wajib diisi.';
    } else if (password.length < 8) {
      errorMessage = 'Password minimal 8 karakter.';
    }

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Respons server tidak valid.');
      }

      if (response.statusCode == 200 &&
          decoded['success'] == true) {
        final rawUser = decoded['data'] ?? decoded['user'];

        final rawToken = decoded['token'] ??
            (rawUser is Map ? rawUser['token'] : null);

        if (rawUser is! Map ||
            rawToken == null ||
            rawToken.toString().trim().isEmpty) {
          throw Exception(
            'Data pengguna atau token dari server tidak lengkap.',
          );
        }

        final userMap = Map<String, dynamic>.from(rawUser);

        final user = UserData.fromJson({
          ...userMap,
          'token': rawToken.toString().trim(),
        });

        if (!user.hasValidProfile) {
          throw Exception(
            'Nama atau email pengguna tidak ditemukan dari server.',
          );
        }

        if (!user.hasToken) {
          throw Exception('Token login tidak valid.');
        }

        // ==================================
        // SIMPAN SESI LOGIN
        // ==================================

        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(
          'user_data',
          jsonEncode(user.toJson()),
        );

        await prefs.setString(
          'token',
          user.token!,
        );

        await prefs.setString(
          'profile_name',
          user.name,
        );

        await prefs.setString(
          'profile_email',
          user.email,
        );

        if (!mounted) return;

        // ==================================
        // MASUK KE HOME
        // ==================================

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              user: user,
            ),
          ),
        );
      } else {
        final message =
            decoded['message']?.toString() ??
                'Login gagal. Periksa email dan password.';

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login gagal. Periksa koneksi atau respons backend. '
            'Detail: $error',
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

  // ==========================================
  // NAVIGASI
  // ==========================================

  void openResetPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ResetPasswordScreen(),
      ),
    );
  }

  void openSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SignupScreen(),
      ),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              maxWidth: 430,
            ),
            color: Colors.white,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: StockLogo(),
                          ),

                          const SizedBox(height: 76),

                          const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(height: 18),

                          const Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),

                          const SizedBox(height: 8),

                          _inputField(
                            controller: emailController,
                            hintText: '',
                            keyboardType: TextInputType.emailAddress,
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),

                          const SizedBox(height: 8),

                          _passwordField(),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: openResetPassword,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 0,
                                ),
                              ),
                              child: const Text(
                                'Forget password?',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF9AAA82),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 43),

                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF587B55),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFF587B55),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: openSignup,
                                  child: const Text(
                                    'Sign up',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF587B55),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 25),

                          _socialButton(
                            type: SocialType.facebook,
                            text: 'Continue with Facebook',
                          ),

                          const SizedBox(height: 12),

                          _socialButton(
                            type: SocialType.google,
                            text: 'Continue with Google',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // INPUT EMAIL
  // ==========================================

  Widget _inputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      height: 41,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: Color(0xFF00C853),
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: Color(0xFF00C853),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: Color(0xFF00C853),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // INPUT PASSWORD
  // ==========================================

  Widget _passwordField() {
    return SizedBox(
      height: 41,
      child: TextField(
        controller: passwordController,
        obscureText: obscurePassword,
        style: const TextStyle(
          fontSize: 14,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 19,
              color: Colors.grey,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: Color(0xFF00C853),
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: Color(0xFF00C853),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: Color(0xFF00C853),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SOCIAL BUTTON
  // ==========================================

  Widget _socialButton({
    required SocialType type,
    required String text,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(
            color: Colors.black,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _socialIcon(type),
            const SizedBox(width: 18),
            Text(
              text,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialIcon(SocialType type) {
    if (type == SocialType.facebook) {
      return Container(
        width: 27,
        height: 27,
        decoration: const BoxDecoration(
          color: Color(0xFF1877F2),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text(
            'f',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return const Text(
      'G',
      style: TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w600,
        color: Color(0xFF4285F4),
      ),
    );
  }
}

// ==========================================
// STOCK.CO LOGO
// ==========================================

class StockLogo extends StatelessWidget {
  const StockLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 23,
          height: 23,
          decoration: BoxDecoration(
            color: const Color(0xFF101914),
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Icon(
            Icons.view_in_ar,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'stock.co',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

enum SocialType {
  facebook,
  google,
}
