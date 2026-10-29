import 'dart:convert';

import 'package:http/http.dart' as http;

/// Sends Identity Toolkit requests using its documented JSON format. Firedart
/// otherwise sends form data, which the Firebase Auth emulator rejects.
class FirebaseAuthClient extends http.BaseClient {
  final http.Client _inner;

  FirebaseAuthClient({http.Client? inner}) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is http.Request &&
        request.url.host == 'identitytoolkit.googleapis.com' &&
        (request.headers['content-type'] ?? '')
            .startsWith('application/x-www-form-urlencoded')) {
      final body = <String, dynamic>{...request.bodyFields};
      for (final key in ['returnSecureToken', 'returnIdpCredential']) {
        if (body.containsKey(key)) body[key] = body[key] == 'true';
      }
      request = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    return _inner.send(request).timeout(const Duration(seconds: 30));
  }

  @override
  void close() => _inner.close();
}
