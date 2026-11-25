
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import 'new_password_screen.dart';

class VerificationCodeScreen extends StatefulWidget {
  final String email;

  const VerificationCodeScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerificationCodeScreen> createState() =>
      _VerificationCodeScreenState();
}

class _VerificationCodeScreenState
    extends State<VerificationCodeScreen> {
  final List<TextEditingController> controllers =
      List.generate(6, (index) => TextEditingController());

  final List<FocusNode> focusNodes =
      List.generate(6, (index) => FocusNode());

  bool showError = false;
  bool isVerified = false;
  bool isLoading = false;
  bool isResending = false;

  String errorMessage = '';

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }

    for (final node in focusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  // ================================================
  // VERIFY CODE
  // ================================================

  Future<void> verifyCode() async {
    if (isLoading) return;

    final code = controllers
        .map((controller) => controller.text)
        .join();

    if (code.length != 6) {
      setState(() {
        showError = true;
        isVerified = false;
        errorMessage = 'Kode verifikasi harus terdiri dari 6 digit';
      });
      return;
    }

    setState(() {
      isLoading = true;
      showError = false;
      isVerified = false;
    });

    try {
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/auth/verify-reset-code',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': widget.email,
          'code': code,
        }),
      );

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        final resetToken = data['resetToken']?.toString() ?? '';

        if (resetToken.isEmpty) {
          setState(() {
            showError = true;
            errorMessage = 'Reset token tidak ditemukan.';
          });
          return;
        }

        setState(() {
          isVerified = true;
          showError = false;
        });

        await Future.delayed(
          const Duration(milliseconds: 500),
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => NewPasswordScreen(
              resetToken: resetToken,
            ),
          ),
        );
      } else {
        setState(() {
          showError = true;
          errorMessage = data['message'] ??
              'Kode verifikasi salah atau sudah kedaluwarsa.';
        });
      }
    } catch (e) {
      debugPrint('VERIFY CODE ERROR: $e');

      if (!mounted) return;

      setState(() {
        showError = true;
        errorMessage =
            'Tidak dapat terhubung ke server. Coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ================================================
  // RESEND CODE
  // ================================================

  Future<void> resendCode() async {
    if (isResending || isLoading) return;

    setState(() {
      isResending = true;
      showError = false;
      isVerified = false;
    });

    try {
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/auth/forgot-password',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': widget.email,
        }),
      );

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        for (final controller in controllers) {
          controller.clear();
        }

        setState(() {
          showError = false;
          isVerified = false;
        });

        FocusScope.of(context).requestFocus(focusNodes[0]);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? 'Permintaan kode baru berhasil.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? 'Gagal mengirim ulang kode.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('RESEND CODE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak dapat terhubung ke server.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isResending = false;
        });
      }
    }
  }

  // ================================================
  // OTP INPUT
  // ================================================

  void onCodeChanged(String value, int index) {
    if (value.length == 1) {
      if (index < 5) {
        FocusScope.of(context).requestFocus(
          focusNodes[index + 1],
        );
      } else {
        FocusScope.of(context).unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(
        focusNodes[index - 1],
      );
    }

    if (showError) {
      setState(() {
        showError = false;
      });
    }
  }

  // ================================================
  // BACK
  // ================================================

  void goBack() {
    Navigator.pop(context);
  }

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
                    horizontal: 32,
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
                        'Verification Code',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Please enter the verification code sent to your\n'
                        'email address',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.45,
                          color: Color(0xFF444444),
                        ),
                      ),

                      const SizedBox(height: 5),

                      // EMAIL

                      Text(
                        widget.email,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF587B55),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // OTP INPUT

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (index) => _otpBox(index),
                        ),
                      ),

                      // ERROR

                      if (showError)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 10,
                            left: 3,
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 13,
                                color: Color(0xFFFF5964),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFFFF5964),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // RESEND

                      Center(
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Didn't receive the code? ",
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF777777),
                              ),
                            ),
                            GestureDetector(
                              onTap: isResending || isLoading
                                  ? null
                                  : resendCode,
                              child: Text(
                                isResending
                                    ? 'Sending...'
                                    : 'Resend Code',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF587B55),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 35),

                      // SUCCESS MESSAGE

                      if (isVerified)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(
                            bottom: 10,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F8EE),
                            borderRadius:
                                BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF38C878),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: Color(0xFF20B968),
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Kode berhasil diverifikasi',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF179957),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // VERIFY BUTTON

                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: isLoading || isResending
                              ? null
                              : verifyCode,
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
                                  'Verify',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // BACK

                      Center(
                        child: GestureDetector(
                          onTap: goBack,
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF587B55),
                              fontWeight: FontWeight.w600,
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
  // OTP BOX
  // ================================================

  Widget _otpBox(int index) {
    return SizedBox(
      width: 43,
      height: 55,
      child: TextField(
        controller: controllers[index],
        focusNode: focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        enabled: !isLoading,
        onChanged: (value) {
          onCodeChanged(value, index);
        },
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF222222),
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF222222),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF222222),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF5F7D5D),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFFF5964),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
