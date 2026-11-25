import 'package:flutter/material.dart';

const Color _bg = Color(0xFFF4F5F8);
const Color _green = Color(0xFF5F7558);
const Color _muted = Color(0xFF6F7580);

class _PageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _PageShell({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF25282D)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF202124))),
              const SizedBox(height: 12),
              Text(subtitle, style: const TextStyle(fontSize: 16, height: 1.45, color: _muted)),
              const SizedBox(height: 28),
              child,
            ],
          ),
        ),
      );
}

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});
  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}
class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _search = TextEditingController();
  final List<Map<String, String>> _faqs = const [
    {'q': 'Bagaimana menambah barang?', 'a': 'Buka Data Barang, pilih Tambah, lalu isi nama, SKU, dan stok awal barang.'},
    {'q': 'Bagaimana mencatat stok keluar?', 'a': 'Pilih Stok Keluar, cari barang, isi jumlah, lalu simpan transaksi.'},
    {'q': 'Siapa yang bisa mengubah akses tim?', 'a': 'Pemilik toko dapat mengatur peran dan akses melalui halaman Anggota Tim.'},
  ];
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final visible = _faqs.where((f) => ('${f['q']} ${f['a']}').toLowerCase().contains(_search.text.toLowerCase())).toList();
    return _PageShell(title: 'Pusat Bantuan', subtitle: 'Temukan jawaban untuk aktivitas toko Anda.', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'Cari topik bantuan', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E5E9))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E5E9))))),
      const SizedBox(height: 24), const Text('PERTANYAAN UMUM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _muted)), const SizedBox(height: 12),
      Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]), child: Column(children: [for (int i = 0; i < visible.length; i++) ...[if (i > 0) const Divider(height: 1, color: Color(0xFFE7E9ED)), Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(visible[i]['q']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(visible[i]['a']!, style: const TextStyle(fontSize: 14, height: 1.5, color: _muted))]))]])),
      const SizedBox(height: 24), Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Masih butuh bantuan?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), SizedBox(height: 12), Row(children: [Icon(Icons.mail_outline, color: _green), SizedBox(width: 10), Text('bantuan@stokku.id', style: TextStyle(color: _green, fontWeight: FontWeight.w600))]), SizedBox(height: 10), Text('Senin–Jumat, 09.00–17.00 WIB', style: TextStyle(color: _muted, fontSize: 13))]))
    ]));
  }
}

