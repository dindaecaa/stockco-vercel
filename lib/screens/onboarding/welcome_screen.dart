import 'package:flutter/material.dart';

import '../auth/signup_screen.dart';
import '../auth/login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color navy = Color(0xFF14182D);
  static const Color sageTop = Color(0xFFDDE5C7);
  static const Color sageBottom = Color(0xFF304B40);
  static const Color accentRed = Color(0xFFFF4949);

  void _openSignup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SignupScreen(),
      ),
    );
  }

  void _openLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  void _showSocialMessage(BuildContext context, String platform) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$platform login belum tersedia'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.height < 750;

    return Scaffold(
      backgroundColor: sageBottom,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              sageTop,
              Color(0xFFB5C5A1),
              sageBottom,
            ],
            stops: [0.04, 0.38, 0.86],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // PRODUCT IMAGE
                      SizedBox(
                        height: constraints.maxHeight *
                            (compact ? 0.39 : 0.43),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            22,
                            8,
                            22,
                            0,
                          ),
                          child: Image.asset(
                            'assets/images/stock_welcome.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.headphones,
                                  color: navy,
                                  size: 90,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // TITLE
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to',
                              style: TextStyle(
                                color: navy,
                                fontSize: compact ? 35 : 40,
                                fontWeight: FontWeight.w900,
                                height: 1.08,
                                letterSpacing: -1.2,
                              ),
                            ),
                            Text(
                              'stock.co',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 35 : 40,
                                fontWeight: FontWeight.w900,
                                height: 1.08,
                                letterSpacing: -1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: compact ? 28 : 40),

                      // EMAIL BUTTON
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 44,
                        ),
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () => _openSignup(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: navy,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const StadiumBorder(),
                            ),
                            child: const Text(
                              'Start with email',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: compact ? 27 : 35),

                      // SIGN IN WITH DIVIDER
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color: Colors.white70,
                                thickness: 1.2,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text(
                                'Sign in with',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color: Colors.white70,
                                thickness: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: compact ? 25 : 33),

                      // FACEBOOK BUTTON
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                        ),
                        child: _socialButton(
                          icon: const _FacebookIcon(),
                          text: 'Continue with Facebook',
                          onPressed: () {
                            _showSocialMessage(context, 'Facebook');
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      // GOOGLE BUTTON
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                        ),
                        child: _socialButton(
                          icon: const _GoogleIcon(),
                          text: 'Continue with Google',
                          onPressed: () {
                            _showSocialMessage(context, 'Google');
                          },
                        ),
                      ),

                      SizedBox(height: compact ? 18 : 24),

                      // SIGN IN LINK
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _openLogin(context),
                              child: const Text(
                                'Sign in',
                                style: TextStyle(
                                  color: accentRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required Widget icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFDFDFD),
          foregroundColor: navy,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// FACEBOOK ICON
class _FacebookIcon extends StatelessWidget {
  const _FacebookIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFF426CF5),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(
          'f',
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// GOOGLE ICON
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 32,
      height: 32,
      child: Center(
        child: Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
            children: [
              TextSpan(
                text: 'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}