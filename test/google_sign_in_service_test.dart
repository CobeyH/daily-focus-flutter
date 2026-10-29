import 'dart:convert';
import 'dart:io';

import 'package:daily_focus/services/google_sign_in_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loopback callback rejects a wrong state before accepting a token',
      () async {
    final client = HttpClient();
    Future<void>? browserWork;
    Future<void> completeInBrowser(Uri url) async {
      final params = Uri.splitQueryString(url.fragment);
      final callback = Uri.parse(params['callback']!);
      final responsePage = await (await client.getUrl(callback)).close();
      expect(responsePage.headers.contentType?.mimeType, 'text/html');
      expect(
          await utf8.decoder.bind(responsePage).join(), contains('/complete'));

      Future<int> complete(String state) async {
        final request =
            await client.postUrl(callback.replace(path: '/complete'));
        request.headers
          ..contentType = ContentType.json
          ..set('Origin', callback.origin);
        final data =
            utf8.encode(jsonEncode({'state': state, 'idToken': 'test-token'}));
        request.contentLength = data.length;
        request.add(data);
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode;
      }

      expect(await complete('wrong-state'), HttpStatus.badRequest);
      expect(await complete(params['state']!), HttpStatus.ok);
    }

    final service = GoogleSignInService(launch: (url) async {
      browserWork = completeInBrowser(url);
      return true;
    });
    try {
      expect(await service.signIn(), 'test-token');
      await browserWork;
    } finally {
      client.close(force: true);
    }
  });
}
