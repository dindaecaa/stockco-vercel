
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class AiStockNotification {
  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Future<void> show(
    BuildContext context, {
    String? token,
    bool showWhenEmpty = true,
    VoidCallback? onFillStock,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final authToken = token != null && token.trim().isNotEmpty
          ? token.trim()
          : prefs.getString('token')?.trim();

      if (authToken == null || authToken.isEmpty) {
        if (!context.mounted) return;

        await _showDialog(
          context,
          products: [],
          error: 'Sesi login tidak ditemukan. Silakan login kembali.',
          onFillStock: onFillStock,
        );
        return;
      }

      // Ambil data sebelum popup ditampilkan.
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/products'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Server mengembalikan status ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map ||
          decoded['success'] != true ||
          decoded['data'] is! List) {
        throw Exception(
          'Format data produk dari server tidak sesuai.',
        );
      }

      final products = (decoded['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((product) {
        final stock = _readInt(product['stock']);
        final minimumStock = _readInt(product['minimum_stock']);

        // Stok 0 juga termasuk stok yang perlu diperhatikan.
        return stock >= 0 && stock <= minimumStock;
      }).toList();

      if (!context.mounted) return;

      // Jika stok aman, popup otomatis tidak ditampilkan.
      if (products.isEmpty && !showWhenEmpty) return;

      await _showDialog(
        context,
        products: products,
        onFillStock: onFillStock,
      );
    } catch (error) {
      if (!context.mounted) return;

      await _showDialog(
        context,
        products: [],
        error: error.toString().replaceFirst('Exception: ', ''),
        onFillStock: onFillStock,
      );
    }
  }

  static Future<void> _showDialog(
    BuildContext context, {
    required List<Map<String, dynamic>> products,
    String? error,
    VoidCallback? onFillStock,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.50),
      builder: (_) => _AiStockDialog(
        products: products,
        error: error,
        onFillStock: onFillStock,
      ),
    );
  }
}

class _AiStockDialog extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final String? error;
  final VoidCallback? onFillStock;

  const _AiStockDialog({
    required this.products,
    this.error,
    this.onFillStock,
  });

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    final hasProducts = products.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 29,
                      color: Color(0xFF4168E8),
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifikasi Stok AI',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF172033),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Pemantauan persediaan barang',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF697386),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF697386),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (hasError)
                _buildError()
              else if (!hasProducts)
                _buildEmpty()
              else ...[
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFE18A32),
                      size: 19,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${products.length} barang memiliki stok menipis',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF30343B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: products.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      return _buildProductCard(products[index]);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        onFillStock?.call();
                      });
                    },
                    icon: const Icon(Icons.add_box_outlined, size: 19),
                    label: const Text('Isi stok sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4168E8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name']?.toString() ?? 'Barang tanpa nama';
    final sku = product['sku']?.toString() ?? '-';
    final stock = _readInt(product['stock']);
    final minimumStock = _readInt(product['minimum_stock']);
    final unit = product['unit']?.toString() ?? 'pcs';

    final location = product['location'] ??
        product['rack'] ??
        product['location_name'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE6EAF0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'SKU: $sku',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF7A8496),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _InfoItem(
                  title: 'Sisa stok',
                  value: '$stock $unit',
                ),
              ),
              Expanded(
                child: _InfoItem(
                  title: 'Batas minimum',
                  value: '$minimumStock $unit',
                ),
              ),
              Icon(
                stock == 0
                    ? Icons.error_outline
                    : Icons.warning_amber_rounded,
                color: const Color(0xFFE18A32),
                size: 22,
              ),
            ],
          ),
          if (location != null &&
              location.toString().trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Color(0xFF697386),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF697386),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Color(0xFF55A66A),
            size: 42,
          ),
          SizedBox(height: 10),
          Text(
            'Semua stok barang aman!',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF30343B),
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Tidak ada barang yang berada di bawah batas minimum stok.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF697386),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Color(0xFFD47735),
            size: 40,
          ),
          const SizedBox(height: 10),
          const Text(
            'Data stok belum dapat dimuat',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF30343B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF697386),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String title;
  final String value;

  const _InfoItem({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF7A8496),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF172033),
          ),
        ),
      ],
    );
  }
}
