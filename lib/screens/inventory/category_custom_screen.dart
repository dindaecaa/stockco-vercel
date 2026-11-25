
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_screen.dart';
import '../scanner/scanner_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';

const String _baseUrl = kIsWeb
    ? 'http://localhost:3001'
    : 'http://10.0.2.2:3001';

const Color _green = Color(0xFF587B55);
const Color _muted = Color(0xFF718096);

class CategoryCustomScreen extends StatefulWidget {
  const CategoryCustomScreen({super.key});

  @override
  State<CategoryCustomScreen> createState() =>
      _CategoryCustomScreenState();
}

class _CategoryCustomScreenState extends State<CategoryCustomScreen> {
  final TextEditingController searchController =
      TextEditingController();

  List<CategoryData> categories = [];

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // HEADER AUTENTIKASI
  // =========================================================

  Future<Map<String, String>?> _headers({
    bool withBody = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      return null;
    }

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (withBody) 'Content-Type': 'application/json',
    };
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _responseMessage(
    Map<String, dynamic> body,
    String fallback,
  ) {
    return body['message']?.toString() ?? fallback;
  }

  // =========================================================
  // GET KATEGORI
  // =========================================================

  Future<void> fetchCategories() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final headers = await _headers();

      if (headers == null) {
        throw Exception(
          'Sesi login tidak ditemukan. Silakan login kembali.',
        );
      }

      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/categories'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if (body is! Map<String, dynamic>) {
        throw Exception('Format respons server tidak valid.');
      }

      if (response.statusCode != 200 ||
          body['success'] != true) {
        throw Exception(
          _responseMessage(
            body,
            'Gagal mengambil kategori.',
          ),
        );
      }

      final List<dynamic> data = body['data'] ?? [];

      final result = data.map((item) {
        return CategoryData.fromJson(
          Map<String, dynamic>.from(item),
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        categories = result;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  // =========================================================
  // TAMBAH KATEGORI
  // =========================================================

  Future<bool> addCategory({
    required String name,
    required String description,
  }) async {
    if (isSaving) return false;

    setState(() => isSaving = true);

    try {
      final headers = await _headers(withBody: true);

      if (headers == null) {
        throw Exception(
          'Sesi login tidak ditemukan. Silakan login kembali.',
        );
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/categories'),
            headers: headers,
            body: jsonEncode({
              'name': name,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if (body is! Map<String, dynamic>) {
        throw Exception('Format respons server tidak valid.');
      }

      if (response.statusCode != 201 ||
          body['success'] != true) {
        throw Exception(
          _responseMessage(
            body,
            'Gagal menambahkan kategori.',
          ),
        );
      }

      await fetchCategories();

      _showMessage('Kategori berhasil ditambahkan.');
      return true;
    } catch (error) {
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  // =========================================================
  // EDIT KATEGORI
  // =========================================================

  Future<bool> updateCategory({
    required int id,
    required String name,
    required String description,
  }) async {
    if (isSaving) return false;

    setState(() => isSaving = true);

    try {
      final headers = await _headers(withBody: true);

      if (headers == null) {
        throw Exception(
          'Sesi login tidak ditemukan. Silakan login kembali.',
        );
      }

      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/categories/$id'),
            headers: headers,
            body: jsonEncode({
              'name': name,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if (body is! Map<String, dynamic>) {
        throw Exception('Format respons server tidak valid.');
      }

      if (response.statusCode != 200 ||
          body['success'] != true) {
        throw Exception(
          _responseMessage(
            body,
            'Gagal memperbarui kategori.',
          ),
        );
      }

      await fetchCategories();

      _showMessage('Kategori berhasil diperbarui.');
      return true;
    } catch (error) {
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  // =========================================================
  // FILTER KATEGORI
  // =========================================================

  List<CategoryData> get filteredCategories {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) return categories;

    return categories.where((category) {
      return category.name.toLowerCase().contains(query) ||
          category.description.toLowerCase().contains(query);
    }).toList();
  }

  // =========================================================
  // DIALOG TAMBAH
  // =========================================================

  void showAddCategoryDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool dialogSaving = false;

        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Tambah Kategori',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF202124),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(
                      controller: nameController,
                      label: 'Nama Kategori',
                      hint: 'Contoh: Smart Home',
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      controller: descriptionController,
                      label: 'Deskripsi',
                      hint: 'Contoh: Produk smart home',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: _muted),
                  ),
                ),
                ElevatedButton(
                  onPressed: dialogSaving
                      ? null
                      : () async {
                          final name =
                              nameController.text.trim();

                          final description =
                              descriptionController.text.trim();

                          if (name.isEmpty) {
                            _showMessage(
                              'Nama kategori wajib diisi.',
                            );
                            return;
                          }

                          dialogSetState(() {
                            dialogSaving = true;
                          });

                          final success = await addCategory(
                            name: name,
                            description: description,
                          );

                          if (!dialogContext.mounted) return;

                          if (success) {
                            Navigator.pop(dialogContext);
                          } else {
                            dialogSetState(() {
                              dialogSaving = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: dialogSaving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      descriptionController.dispose();
    });
  }

  // =========================================================
  // DIALOG EDIT
  // =========================================================

  void showEditCategoryDialog(CategoryData category) {
    final nameController = TextEditingController(
      text: category.name,
    );

    final descriptionController = TextEditingController(
      text: category.description == 'Belum ada deskripsi'
          ? ''
          : category.description,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool dialogSaving = false;

        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Edit Kategori',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF202124),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(
                      controller: nameController,
                      label: 'Nama Kategori',
                      hint: 'Nama kategori',
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      controller: descriptionController,
                      label: 'Deskripsi',
                      hint: 'Deskripsi kategori',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: _muted),
                  ),
                ),
                ElevatedButton(
                  onPressed: dialogSaving
                      ? null
                      : () async {
                          final name =
                              nameController.text.trim();

                          final description =
                              descriptionController.text.trim();

                          if (name.isEmpty) {
                            _showMessage(
                              'Nama kategori wajib diisi.',
                            );
                            return;
                          }

                          dialogSetState(() {
                            dialogSaving = true;
                          });

                          final success = await updateCategory(
                            id: category.id,
                            name: name,
                            description: description,
                          );

                          if (!dialogContext.mounted) return;

                          if (success) {
                            Navigator.pop(dialogContext);
                          } else {
                            dialogSetState(() {
                              dialogSaving = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: dialogSaving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      descriptionController.dispose();
    });
  }

  // =========================================================
  // DIALOG FIELD
  // =========================================================

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF30343B),
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB4BBC5),
            ),
            filled: true,
            fillColor: const Color(0xFFF7F8FA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final filtered = filteredCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 60,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Color(0xFF4E7DEB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'Kategori Kustom',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202124),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: fetchCategories,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    11,
                    12,
                    18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Barang lebih rapi, mudah dicari',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF30343B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Kelompokkan barang sesuai kebutuhan toko.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 9),

                      // SEARCH

                      Container(
                        height: 35,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE1E5EB),
                          ),
                        ),
                        child: TextField(
                          controller: searchController,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF30343B),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.search,
                              size: 16,
                              color: _muted,
                            ),
                            hintText: 'Cari kategori...',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9AA3B2),
                            ),
                            contentPadding: EdgeInsets.only(
                              right: 8,
                              bottom: 7,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 9),

                      // HEADER DAFTAR

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Daftar Kategori',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF30343B),
                            ),
                          ),
                          Text(
                            '${categories.length} kategori',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 7),

                      // LIST KATEGORI

                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.all(35),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: _green,
                            ),
                          ),
                        )
                      else if (errorMessage != null)
                        _buildErrorState()
                      else if (filtered.isEmpty)
                        _buildEmptyState()
                      else
                        ...filtered.map(_buildCategoryCard),

                      const SizedBox(height: 4),

                      // TAMBAH KATEGORI

                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: isLoading || isSaving
                              ? null
                              : showAddCategoryDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, size: 18),
                              SizedBox(width: 5),
                              Text(
                                'Tambah Kategori',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 9),

                      // INFORMATION

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3E7),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: _green,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ketuk ikon pensil untuk mengubah nama atau mengelola kategori.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: _green,
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // =========================================================
  // ERROR STATE
  // =========================================================

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: _muted,
            size: 35,
          ),
          const SizedBox(height: 10),
          const Text(
            'Gagal memuat kategori',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF30343B),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            errorMessage ?? 'Terjadi kesalahan.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _muted,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: fetchCategories,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CATEGORY CARD
  // =========================================================

  Widget _buildCategoryCard(CategoryData category) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF3ECFF),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.category_outlined,
              size: 18,
              color: Color(0xFF8D4DE8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF30343B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${category.itemCount} jenis barang',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  category.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: isSaving
                ? null
                : () => showEditCategoryDialog(category),
            child: Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: _muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20, bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 25,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFF3ECFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.category_outlined,
              color: Color(0xFF8D4DE8),
              size: 25,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada kategori',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF30343B),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Tambahkan kategori untuk mengelompokkan barang.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  Widget _buildBottomNavigation() {
    return Container(
      height: 82,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFECEEF1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _bottomItem(
              icon: Icons.home_outlined,
              label: 'Home',
              onTap: () => _openPage(const HomeScreen()),
            ),
          ),
          Expanded(
            child: _bottomItem(
              icon: Icons.qr_code_scanner,
              label: 'Scanner',
              onTap: () => _openPage(const ScannerScreen()),
            ),
          ),
          Expanded(
            child: _bottomItem(
              icon: Icons.receipt_long_outlined,
              label: 'Riwayat',
              onTap: () => _openPage(const HistoryScreen()),
            ),
          ),
          Expanded(
            child: _bottomItem(
              icon: Icons.person_outline,
              label: 'Profil',
              onTap: () => _openPage(const ProfileScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _bottomItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 27, color: _muted),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: _muted,
              ),
            ),
            const SizedBox(height: 9),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// MODEL KATEGORI
// =========================================================

class CategoryData {
  final int id;
  final String name;
  final int itemCount;
  final String description;

  const CategoryData({
    required this.id,
    required this.name,
    required this.itemCount,
    required this.description,
  });

  factory CategoryData.fromJson(Map<String, dynamic> json) {
    return CategoryData(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      itemCount: int.tryParse(
            json['item_count']?.toString() ?? '0',
          ) ??
          0,
      description: json['description'] == null ||
              json['description'].toString().trim().isEmpty
          ? 'Belum ada deskripsi'
          : json['description'].toString(),
    );
  }
}
