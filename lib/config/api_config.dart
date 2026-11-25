
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host;

      // Jika dijalankan secara lokal di komputer.
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:3001';
      }

      // Jika sudah di-deploy, gunakan backend Vercel.
      return 'https://stockco-backend.vercel.app';
    }

    // Jika dijalankan melalui Android Emulator.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return kReleaseMode
          ? 'https://stockco-backend.vercel.app'
          : 'http://10.0.2.2:3001';
    }

    // Platform lainnya.
    return kReleaseMode
        ? 'https://stockco-backend.vercel.app'
        : 'http://localhost:3001';
  }
}
