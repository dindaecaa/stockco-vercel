
class UserData {
  final int? id;
  String name;
  String email;
  final String role;
  String? token;

  UserData({
    this.id,
    required this.name,
    required this.email,
    this.role = 'user',
    this.token,
  });

  // ==========================================
  // MEMBACA DATA USER DARI JSON
  // ==========================================

  factory UserData.fromJson(Map<String, dynamic> json) {
    // Mendukung beberapa bentuk respons backend:
    // {id, name, email, role, token}
    // {user: {...}, token: "..."}
    // {data: {...}, token: "..."}
    // {data: {user: {...}}, token: "..."}

    Map<String, dynamic> userJson = json;

    final data = json['data'];

    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);

      if (dataMap['user'] is Map) {
        userJson = Map<String, dynamic>.from(
          dataMap['user'],
        );
      } else {
        userJson = dataMap;
      }
    } else if (json['user'] is Map) {
      userJson = Map<String, dynamic>.from(
        json['user'],
      );
    }

    final userId = userJson['id'];

    // Token bisa berada di respons utama atau data user.
    final tokenValue =
        json['token'] ??
        (data is Map ? data['token'] : null) ??
        userJson['token'];

    return UserData(
      id: userId is int
          ? userId
          : int.tryParse(userId?.toString() ?? ''),
      name: (userJson['name'] ?? '').toString().trim(),
      email: (userJson['email'] ?? '').toString().trim(),
      role: (userJson['role'] ?? 'user')
          .toString()
          .trim()
          .toLowerCase(),
      token: tokenValue?.toString(),
    );
  }

  // ==========================================
  // MENGUBAH USER MENJADI JSON
  // ==========================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'token': token,
    };
  }

  // ==========================================
  // MEMPERBARUI DATA USER
  // ==========================================

  UserData copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
    String? token,
  }) {
    return UserData(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      token: token ?? this.token,
    );
  }

  // ==========================================
  // VALIDASI DATA USER
  // ==========================================

  bool get hasValidProfile {
    return name.trim().isNotEmpty &&
        email.trim().isNotEmpty;
  }

  bool get hasToken {
    return token != null && token!.trim().isNotEmpty;
  }

  // ==========================================
  // ROLE USER
  // ==========================================

  bool get isAdmin => role == 'admin';

  bool get isOwner => role == 'owner';

  bool get isStaff =>
      role == 'staff' || role == 'pegawai';

  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'owner':
        return 'Owner';
      case 'staff':
      case 'pegawai':
        return 'Staff';
      default:
        return 'User';
    }
  }
}
