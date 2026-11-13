import 'dart:convert';
import 'dart:io';

import 'package:daily_focus/services/google_sign_in_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  test('Android uses the native picker without opening a browser', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var calls = 0;
    final service = GoogleSignInService(
      nativeSignIn: () async {
        calls++;
        return 'native-google-token';
      },
      launch: (_) async => throw StateError('Browser must not open on Android'),
    );
    expect(await service.signIn(), 'native-google-token');
    expect(calls, 1);
  });

  test('canceling the native picker never falls back to a browser', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final service = GoogleSignInService(
      nativeSignIn: () async => throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled),
      launch: (_) async => throw StateError('Browser must not open'),
    );
    await expectLater(service.signIn(), throwsA(isA<GoogleSignInException>()));
  });

  test('loopback callback rejects a wrong state before accepting a token',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
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
