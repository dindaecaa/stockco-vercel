
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const Color _bg = Color(0xFFF4F5F8);
const Color _green = Color(0xFF5F7558);
const Color _muted = Color(0xFF6F7580);

const int _ownerAccountId = 8;

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

class TeamMembersScreen extends StatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  State<TeamMembersScreen> createState() =>
      _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  final List<Map<String, dynamic>> _members = [];
  final List<Map<String, dynamic>> _branches = [];

  Map<String, dynamic>? _owner;

  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isOwner = false;

  String? _errorMessage;
  String? _token;

  int? _userId;

  String get _baseUrl {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001';
    }

    return 'http://localhost:3001';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null && _token!.isNotEmpty)
          'Authorization': 'Bearer $_token',
      };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // =====================================
  // INITIALIZE SESSION
  // =====================================

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _token = prefs.getString('token');

      final userDataString = prefs.getString('user_data');

      if (userDataString != null) {
        final userData =
            jsonDecode(userDataString) as Map<String, dynamic>;

        _userId = int.tryParse(
          userData['id']?.toString() ?? '',
        );
      }

      _isOwner = _userId == _ownerAccountId;

      if (!mounted) return;

      if (_token == null || _token!.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Sesi login tidak ditemukan. Silakan login kembali.';
        });
        return;
      }

      if (!_isOwner) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Hanya Owner yang dapat mengelola anggota tim.';
        });
        return;
      }

      await Future.wait([
        _loadTeamMembers(),
        _loadBranches(),
      ]);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat sesi login.';
      });

      debugPrint('Initialize team error: $error');
    }
  }

  // =====================================
  // RESPONSE HELPER
  // =====================================

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception('Format respons server tidak valid.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  String _responseMessage(
    Map<String, dynamic> decoded,
    String fallback,
  ) {
    return decoded['message']?.toString() ?? fallback;
  }

  // =====================================
  // LOAD TEAM MEMBERS
  // =====================================

  Future<void> _loadTeamMembers() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/team'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      final decoded = _decodeResponse(response);

      if (response.statusCode == 200 &&
          decoded['success'] == true) {
        final data = decoded['data'];

        if (data is! Map) {
          throw Exception('Data anggota tim tidak valid.');
        }

        final ownerData = data['owner'];
        final memberData = data['members'];

        if (ownerData is! Map || memberData is! List) {
          throw Exception('Format data anggota tim tidak sesuai.');
        }

        if (!mounted) return;

        setState(() {
          _owner = Map<String, dynamic>.from(ownerData);

          _members
            ..clear()
            ..addAll(
              memberData.map(
                (item) => Map<String, dynamic>.from(item),
              ),
            );

          _errorMessage = null;
          _isLoading = false;
        });
      } else {
        throw Exception(
          _responseMessage(
            decoded,
            'Gagal mengambil anggota tim.',
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error
            .toString()
            .replaceFirst('Exception: ', '');
      });

      debugPrint('Load team members error: $error');
    }
  }

  // =====================================
  // LOAD BRANCHES
  // =====================================

  Future<void> _loadBranches() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/branches'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      final decoded = _decodeResponse(response);

      if (response.statusCode == 200 &&
          decoded['success'] == true) {
        final data = decoded['data'];

        if (data is! List) return;

        if (!mounted) return;

        setState(() {
          _branches
            ..clear()
            ..addAll(
              data.map(
                (item) => Map<String, dynamic>.from(item),
              ),
            );
        });
      } else {
        debugPrint(
          'Load branches: ${decoded['message']}',
        );
      }
    } catch (error) {
      debugPrint('Load branches error: $error');
    }
  }

  // =====================================
  // REFRESH
  // =====================================

  Future<void> _refreshData() async {
    if (!_isOwner || _token == null) return;

    await Future.wait([
      _loadTeamMembers(),
      _loadBranches(),
    ]);
  }

  // =====================================
  // SNACKBAR
  // =====================================

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
          backgroundColor:
              isError ? Colors.red.shade700 : _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // =====================================
  // INVITE MEMBER
  // =====================================

  Future<void> _addMember() async {
    if (!_isOwner || _isProcessing) return;

    final emailController = TextEditingController();
    int? selectedBranchId;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Tambah Anggota',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masukkan email akun Stock.co yang ingin '
                      'ditambahkan ke tim Anda.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email anggota',
                        hintText: 'anggota@email.com',
                        prefixIcon:
                            const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Pilih cabang',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: selectedBranchId ?? -1,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: -1,
                          child: Text('Tanpa cabang'),
                        ),
                        ..._branches.map(
                          (branch) => DropdownMenuItem<int>(
                            value: int.parse(
                              branch['id'].toString(),
                            ),
                            child: Text(
                              branch['name'].toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedBranchId =
                              value == -1 ? null : value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Anggota harus sudah memiliki akun Stock.co. '
                      'Pemilik cukup memasukkan email anggota.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final email =
                        emailController.text.trim();

                    if (email.isEmpty) return;

                    Navigator.pop(
                      dialogContext,
                      {
                        'email': email,
                        'branch_id': selectedBranchId,
                      },
                    );
                  },
                  child: const Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();

    if (result == null) return;

    await _inviteMember(
      email: result['email'] as String,
      branchId: result['branch_id'] as int?,
    );
  }

  Future<void> _inviteMember({
    required String email,
    int? branchId,
  }) async {
    if (!_isOwner || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/team/invite'),
            headers: _headers,
            body: jsonEncode({
              'email': email,
              'branch_id': branchId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = _decodeResponse(response);

      if (response.statusCode == 201 &&
          decoded['success'] == true) {
        _showMessage('Anggota berhasil ditambahkan!');
        await _loadTeamMembers();
      } else {
        _showMessage(
          _responseMessage(
            decoded,
            'Gagal menambahkan anggota.',
          ),
          isError: true,
        );
      }
    } catch (error) {
      _showMessage(
        'Tidak dapat menghubungi server. Periksa koneksi API.',
        isError: true,
      );
      debugPrint('Invite member error: $error');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // =====================================
  // UPDATE MEMBER ROLE
  // =====================================

  Future<void> _changeRole(
    Map<String, dynamic> member,
    String newRole,
  ) async {
    if (!_isOwner || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final response = await http
          .patch(
            Uri.parse(
              '$_baseUrl/api/team/${member['id']}/role',
            ),
            headers: _headers,
            body: jsonEncode({
              'role': newRole,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = _decodeResponse(response);

      if (response.statusCode == 200 &&
          decoded['success'] == true) {
        _showMessage('Role anggota berhasil diperbarui.');
        await _loadTeamMembers();
      } else {
        _showMessage(
          _responseMessage(
            decoded,
            'Gagal mengubah role.',
          ),
          isError: true,
        );
      }
    } catch (error) {
      _showMessage(
        'Gagal menghubungi server.',
        isError: true,
      );
      debugPrint('Change role error: $error');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // =====================================
  // DELETE MEMBER
  // =====================================

  Future<void> _deleteMember(
    Map<String, dynamic> member,
  ) async {
    if (!_isOwner || _isProcessing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Anggota?'),
        content: Text(
          'Apakah kamu yakin ingin menghapus '
          '${member['name']} dari tim?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final response = await http
          .delete(
            Uri.parse(
              '$_baseUrl/api/team/${member['id']}',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      final decoded = _decodeResponse(response);

      if (response.statusCode == 200 &&
          decoded['success'] == true) {
        _showMessage('Anggota berhasil dihapus.');
        await _loadTeamMembers();
      } else {
        _showMessage(
          _responseMessage(
            decoded,
            'Gagal menghapus anggota.',
          ),
          isError: true,
        );
      }
    } catch (error) {
      _showMessage(
        'Gagal menghubungi server.',
        isError: true,
      );
      debugPrint('Delete member error: $error');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // =====================================
  // ROLE LABEL
  // =====================================

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'leader':
        return 'Leader';
      case 'staff':
        return 'Staff';
      default:
        return role;
    }
  }

  // =====================================
  // MEMBER CARD
  // =====================================

  Widget _memberCard({
    required String name,
    required String email,
    required String branch,
    required String role,
    required String initial,
    bool isOwner = false,
    Map<String, dynamic>? member,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isOwner
                    ? const Color(0xFF6D7488)
                    : const Color(0xFFEDF2EB),
                foregroundColor:
                    isOwner ? Colors.white : _green,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isOwner && member != null)
                PopupMenuButton<String>(
                  enabled: !_isProcessing && _isOwner,
                  onSelected: (value) {
                    if (value.startsWith('role:')) {
                      final newRole = value.substring(5);
                      _changeRole(member, newRole);
                    } else if (value == 'delete') {
                      _deleteMember(member);
                    }
                  },
                  itemBuilder: (_) => [
                    for (final itemRole in [
                      'admin',
                      'leader',
                      'staff',
                    ])
                      if (itemRole != member['role'])
                        PopupMenuItem<String>(
                          value: 'role:$itemRole',
                          child: Text(
                            'Ubah ke ${_roleLabel(itemRole)}',
                          ),
                        ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        'Hapus anggota',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  branch,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _muted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF3EC),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  role,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================
  // BUILD
  // =====================================

  @override
  Widget build(BuildContext context) {
    final totalMembers = _members.length + 1;

    return _PageShell(
      title: 'Anggota Tim',
      subtitle: 'Atur anggota dan hak akses di toko Anda.',
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(
                  color: _green,
                ),
              ),
            )
          : _errorMessage != null
              ? _buildError()
              : _buildContent(totalMembers),
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 55,
          color: _muted,
        ),
        const SizedBox(height: 14),
        Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _muted,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _refreshData,
          icon: const Icon(Icons.refresh),
          label: const Text('Coba Lagi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(int totalMembers) {
    final ownerName =
        _owner?['name']?.toString() ?? 'Pemilik';

    final ownerEmail =
        _owner?['email']?.toString() ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$totalMembers ANGGOTA AKTIF',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
            ),
            IconButton(
              onPressed: _refreshData,
              tooltip: 'Muat ulang',
              icon: const Icon(
                Icons.refresh,
                color: _green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
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
            children: [
              _memberCard(
                name: '$ownerName (Anda)',
                email: ownerEmail,
                branch: 'Semua cabang',
                role: 'Pemilik',
                initial: ownerName.isNotEmpty
                    ? ownerName.substring(0, 1).toUpperCase()
                    : 'P',
                isOwner: true,
              ),
              for (final member in _members) ...[
                const Divider(
                  height: 1,
                  color: Color(0xFFE7E9ED),
                ),
                _memberCard(
                  name: member['name']?.toString() ?? '-',
                  email: member['email']?.toString() ?? '-',
                  branch:
                      member['branch_name']?.toString() ??
                          'Belum ditentukan',
                  role: _roleLabel(
                    member['role']?.toString() ?? 'staff',
                  ),
                  initial:
                      (member['name']?.toString().isNotEmpty ??
                              false)
                          ? member['name']
                              .toString()
                              .substring(0, 1)
                              .toUpperCase()
                          : '?',
                  member: member,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _addMember,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Tambah Anggota',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Pemilik mengelola semua akses. Admin mengelola '
          'stok, Leader membantu mengawasi aktivitas tim, '
          'sedangkan Staff mencatat aktivitas harian.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: _muted,
          ),
        ),
      ],
    );
  }
}

