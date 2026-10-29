import 'dart:convert';

import 'package:firedart/firedart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps Firebase sessions in the OS credential store, separate from task data.
class FirebaseTokenStore extends TokenStore {
  static const _key = 'daily_focus.firebase.session.v1';
  final FlutterSecureStorage _storage;
  final Token? _initialToken;
  Future<void> _pending = Future.value();

  FirebaseTokenStore._(this._storage, this._initialToken);

  static Future<FirebaseTokenStore> open({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) async {
    final saved = await storage.read(key: _key);
    Token? token;
    if (saved != null) {
      try {
        token = Token.fromMap(jsonDecode(saved) as Map<String, dynamic>);
      } on FormatException {
        await storage.delete(key: _key);
      } on TypeError {
        await storage.delete(key: _key);
      }
    }
    return FirebaseTokenStore._(storage, token);
  }

  @override
  Token? read() => _initialToken;

  @override
  void write(Token? token) {
    final value = token == null ? null : jsonEncode(token.toMap());
    // Serialize writes so a delayed token refresh cannot undo a later sign-out.
    Future<void> save() => value == null
        ? _storage.delete(key: _key)
        : _storage.write(key: _key, value: value);
    _pending = _pending.then((_) => save(),
        onError: (Object _, StackTrace __) => save());
    // Refreshes can enqueue writes outside an explicit sign-in operation.
    // flush() still reports failures to callers that need durable persistence.
    _pending.ignore();
  }

  @override
  void delete() => write(null);

  Future<void> flush() => _pending;
}
