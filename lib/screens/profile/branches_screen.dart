
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  static const _green = Color(0xFF5F7D5D);
  static const _background = Color(0xFFF4F5F8);

  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3001';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001';
    }

    return 'http://localhost:3001';
  }

  List<Map<String, dynamic>> _branches = [];

  bool _loading = true;
  bool _saving = false;
  final Set<int> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  // Mengambil token login.
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Header autentikasi.
  Future<Map<String, String>> _headers() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Sesi login tidak ditemukan. Silakan login kembali.',
      );
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Mengambil pesan dari response backend.
  String _responseMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);

      if (body is Map && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {
      // Jika response bukan JSON.
    }

    return 'Terjadi kesalahan pada server.';
  }

  // GET: Mengambil daftar cabang dari MySQL.
  Future<void> _loadBranches() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final headers = await _headers();

      final response = await http.get(
        Uri.parse('$_baseUrl/api/branches'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        if (body is! Map || body['data'] is! List) {
          throw Exception('Format data cabang tidak valid.');
        }

        final List<Map<String, dynamic>> data =
            (body['data'] as List).map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();

        if (!mounted) return;

        setState(() {
          _branches = data;
        });
      } else {
        throw Exception(_responseMessage(response));
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // POST: Menambahkan cabang ke MySQL.
  Future<void> _addBranch() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah Cabang'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 150,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama cabang',
            hintText: 'Contoh: Cabang Malang',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();

              if (value.isEmpty) return;

              Navigator.pop(dialogContext, value);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.trim().isEmpty || !mounted) {
      return;
    }

    setState(() => _saving = true);

    try {
      final headers = await _headers();

      final response = await http.post(
        Uri.parse('$_baseUrl/api/branches'),
        headers: headers,
        body: jsonEncode({
          'name': name.trim(),
        }),
      );

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body);

        if (body is! Map || body['data'] is! Map) {
          throw Exception('Response tambah cabang tidak valid.');
        }

        final newBranch = Map<String, dynamic>.from(
          body['data'] as Map,
        );

        if (!mounted) return;

        setState(() {
          _branches.insert(0, newBranch);
        });

        _showMessage('Cabang berhasil ditambahkan.');
      } else {
        throw Exception(_responseMessage(response));
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // DELETE: Menghapus cabang dari MySQL.
  Future<void> _deleteBranch(Map<String, dynamic> branch) async {
    final branchId = int.tryParse(
      branch['id'].toString(),
    );

    if (branchId == null) {
      _showMessage('ID cabang tidak valid.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus cabang?'),
        content: Text(
          'Cabang "${branch['name']}" akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingIds.add(branchId));

    try {
      final headers = await _headers();

      final response = await http.delete(
        Uri.parse('$_baseUrl/api/branches/$branchId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        setState(() {
          _branches.removeWhere(
            (item) => item['id'].toString() == branchId.toString(),
          );
        });

        _showMessage('Cabang berhasil dihapus.');
      } else {
        throw Exception(_responseMessage(response));
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _deletingIds.remove(branchId));
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.store_outlined,
              size: 54,
              color: _green,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada cabang',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan tombol Tambah Cabang untuk '
              'mendaftarkan cabang pertama.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _branchList() {
    return RefreshIndicator(
      onRefresh: _loadBranches,
      color: _green,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _branches.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final branch = _branches[index];
          final branchId = int.tryParse(
            branch['id'].toString(),
          );

          final isDeleting = branchId != null &&
              _deletingIds.contains(branchId);

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F0FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.store_outlined,
                  color: _green,
                ),
              ),
              title: Text(
                branch['name']?.toString() ?? '-',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Cabang Stock.co'),
              trailing: isDeleting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _green,
                      ),
                    )
                  : IconButton(
                      tooltip: 'Hapus cabang',
                      onPressed: () => _deleteBranch(branch),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Kelola Cabang'),
        backgroundColor: _background,
        foregroundColor: const Color(0xFF202124),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _loadBranches,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _addBranch,
        backgroundColor: _green,
        foregroundColor: Colors.white,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add),
        label: Text(
          _saving ? 'Menyimpan...' : 'Tambah Cabang',
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: _green,
              ),
            )
          : _branches.isEmpty
              ? _emptyState()
              : _branchList(),
    );
  }
}
