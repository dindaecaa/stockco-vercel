import 'package:flutter/material.dart';

const Color _bg = Color(0xFFF4F5F8);
const Color _green = Color(0xFF5F7558);
const Color _muted = Color(0xFF6F7580);

class _PageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _PageShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Color(0xFF25282D),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 16,
                height: 1.45,
                color: _muted,
              ),
            ),
            const SizedBox(height: 28),
            child,
          ],
        ),
      ),
    );
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _type = 'Saran';

  final TextEditingController _message = TextEditingController();
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    if (_message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesan masukan belum diisi.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF3EC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: _green,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Masukan Berhasil Dikirim',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Terima kasih! Kritik dan saran Anda membantu '
                'kami meningkatkan Stokku.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context, true);
                  },
                  child: const Text('Selesai'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      title: 'Kirim Kritik dan Saran',
      subtitle: 'Masukan Anda membantu Stokku jadi lebih baik.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jenis masukan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: ['Saran', 'Kendala', 'Lainnya']
                      .map((value) {
                    final bool selected = _type == value;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _type = value;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: selected
                                ? const Color(0xFFEEF3EC)
                                : Colors.white,
                            foregroundColor:
                                selected ? _green : _muted,
                            side: BorderSide(
                              color: selected
                                  ? _green
                                  : const Color(0xFFE2E5E9),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            value,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Pesan Anda',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _message,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        'Ceritakan saran atau kendala yang Anda alami...',
                    filled: true,
                    fillColor: const Color(0xFFFAFBFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E5E9),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Email balasan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'nama@email.com',
                    filled: true,
                    fillColor: const Color(0xFFFAFBFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E5E9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _submitFeedback,
              icon: const Icon(Icons.send_outlined),
              label: const Text(
                'Kirim Masukan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Terima kasih! Tim kami akan meninjau setiap masukan '
            'yang Anda kirimkan.',
            style: TextStyle(
              color: _muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}