import 'package:daily_focus/storage/firebase_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores a session from secure storage and persists sign-out last',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = await FirebaseTokenStore.open();
    store.setToken('user-id', 'id-token', 'refresh-token', 3600);
    await store.flush();
    final restored = await FirebaseTokenStore.open();
    expect(restored.userId, 'user-id');
    expect(restored.refreshToken, 'refresh-token');
    restored.setToken('user-id', 'new-token', 'new-refresh-token', 3600);
    restored.clear();
    await restored.flush();
    expect((await FirebaseTokenStore.open()).hasToken, isFalse);
  });
}
