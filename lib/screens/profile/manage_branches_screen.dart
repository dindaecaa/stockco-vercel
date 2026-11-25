
import 'package:flutter/material.dart';

class ManageBranchesScreen extends StatefulWidget {
  const ManageBranchesScreen({super.key});

  @override
  State<ManageBranchesScreen> createState() =>
      _ManageBranchesScreenState();
}

class _ManageBranchesScreenState
    extends State<ManageBranchesScreen> {
  static const green = Color(0xFF5F7457);

  final List<Map<String, dynamic>> _branches = [
    {
      'name': 'Toko Maju Pusat',
      'address': 'Jl. Melati No. 12, Bandung',
      'main': true,
      'members': 3,
    },
    {
      'name': 'Toko Maju Dago',
      'address': 'Jl. Dago No. 28, Bandung',
      'main': false,
      'members': 2,
    },
    {
      'name': 'Toko Maju Antapani',
      'address': 'Jl. Terusan Jakarta No. 8',
      'main': false,
      'members': 2,
    },
  ];

  Future<void> _branchDialog({int? index}) async {
    final nameController = TextEditingController(
      text: index == null ? '' : _branches[index]['name'] as String,
    );
    final addressController = TextEditingController(
      text: index == null ? '' : _branches[index]['address'] as String,
    );
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(index == null ? 'Tambah Cabang' : 'Edit Cabang'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama cabang',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Nama cabang wajib diisi'
                        : null,
              ),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat cabang',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Alamat cabang wajib diisi'
                        : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() {
        final branch = <String, dynamic>{
          'name': nameController.text.trim(),
          'address': addressController.text.trim(),
          'main': index == null ? false : _branches[index]['main'],
          'members': index == null ? 0 : _branches[index]['members'],
        };

        if (index == null) {
          _branches.add(branch);
        } else {
          _branches[index] = branch;
        }
      });
    }

    nameController.dispose();
    addressController.dispose();
  }

  Future<void> _deleteBranch(int index) async {
    if (_branches[index]['main'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cabang utama tidak dapat dihapus.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus cabang?'),
        content: Text(
          'Cabang "${_branches[index]['name']}" akan dihapus dari daftar ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _branches.removeAt(index));
    }
  }

  void _showBranchMenu(int index) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Cabang'),
              onTap: () {
                Navigator.pop(sheetContext);
                _branchDialog(index: index);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              title: const Text('Hapus Cabang'),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteBranch(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(height: 14),
              const Text(
                'Kelola Cabang',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kelola lokasi toko dan anggota setiap cabang.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF737780),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '${_branches.length} CABANG',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF737780),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: List.generate(_branches.length, (index) {
                    final branch = _branches[index];

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDF2EA),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.storefront_outlined,
                                      color: green,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          branch['name'] as String,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          branch['address'] as String,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF737780),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _showBranchMenu(index),
                                    icon: const Icon(Icons.more_horiz),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: branch['main'] == true
                                          ? const Color(0xFFEDF2EA)
                                          : const Color(0xFFF0F1F3),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      branch['main'] == true
                                          ? 'Cabang utama'
                                          : 'Aktif',
                                      style: TextStyle(
                                        color: branch['main'] == true
                                            ? green
                                            : const Color(0xFF737780),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${branch['members']} anggota',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF737780),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (index != _branches.length - 1)
                          const Divider(
                            height: 1,
                            color: Color(0xFFE8E9ED),
                          ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () => _branchDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Tambah Cabang',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Stok dan aktivitas dicatat terpisah untuk setiap cabang.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF737780),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
