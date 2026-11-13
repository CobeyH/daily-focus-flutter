import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/firebase_config.dart';

/// Uses Google's native account picker on Android and browser sign-in on Linux.
/// The browser returns a short-lived Google ID token to a loopback listener;
/// the app exchanges it with Firebase. No client secret is shipped in the app.
class GoogleSignInService {
  final Future<bool> Function(Uri)? launch;
  final Future<String> Function()? nativeSignIn;
  static Future<void>? _nativeInitialization;

  const GoogleSignInService({this.launch, this.nativeSignIn});

  Future<String> signIn() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return (nativeSignIn ?? _signInOnAndroid)();
    }
    return _signInInBrowser();
  }

  static Future<String> _signInOnAndroid() async {
    try {
      await (_nativeInitialization ??= GoogleSignIn.instance
          .initialize(serverClientId: FirebaseConfig.googleServerClientId));
    } catch (_) {
      _nativeInitialization = null;
      rethrow;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw StateError(
          'Google did not return a sign-in token. Please try again.');
    }
    return token;
  }

  Future<String> _signInInBrowser() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final state = base64UrlEncode(
      List.generate(32, (_) => Random.secure().nextInt(256)),
    );
    final origin = 'http://127.0.0.1:${server.port}';
    final result = Completer<String>();
    final listener = server.listen((request) async {
      String? token;
      try {
        if (request.method == 'GET' && request.uri.path == '/callback') {
          request.response.headers
            ..contentType = ContentType.html
            ..set('Cache-Control', 'no-store')
            ..set('Referrer-Policy', 'no-referrer')
            ..set('Content-Security-Policy',
                "default-src 'none'; script-src 'unsafe-inline'; connect-src 'self'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'");
          request.response.write(_callbackPage);
        } else if (request.method == 'POST' &&
            request.uri.path == '/complete' &&
            request.headers.value('origin') == origin &&
            request.contentLength > 0 &&
            request.contentLength < 20000) {
          final body = jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
          if (body['state'] != state ||
              body['idToken'] is! String ||
              (body['idToken'] as String).isEmpty) {
            request.response.statusCode = HttpStatus.badRequest;
          } else if (!result.isCompleted) {
            token = body['idToken'] as String;
            request.response.write('ok');
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
      } catch (_) {
        request.response.statusCode = HttpStatus.badRequest;
      } finally {
        await request.response.close();
        if (token != null && !result.isCompleted) result.complete(token);
      }
    });

    try {
      final url = Uri.parse(FirebaseConfig.googleSignInUrl).replace(
        fragment: Uri(queryParameters: {
          'callback': '$origin/callback',
          'state': state,
        }).query,
      );
      final opened = await (launch?.call(url) ??
          launchUrl(url, mode: LaunchMode.externalApplication));
      if (!opened) {
        throw StateError('Could not open your browser for Google sign-in.');
      }
      return await result.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException(
          'Google sign-in was not completed. Please try again.',
        ),
      );
    } finally {
      await listener.cancel();
      await server.close(force: true);
    }
  }
}

const _callbackPage = '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Daily Focus sign-in</title>
<style>body{font:18px system-ui;max-width:36rem;margin:15vh auto;padding:24px}</style>
<h1>Finishing sign-in…</h1><p id="status">Please keep this page open.</p>
<script>
const params = new URLSearchParams(location.hash.slice(1));
history.replaceState(null, '', '/callback');
fetch('/complete', {method:'POST', headers:{'Content-Type':'application/json'},
  body:JSON.stringify({state:params.get('state'), idToken:params.get('idToken')})})
  .then(response => { if (!response.ok) throw Error();
    document.querySelector('h1').textContent = 'You can return to Daily Focus';
    document.getElementById('status').textContent = 'You may close this tab.';
  }).catch(() => { document.getElementById('status').textContent =
    'Could not finish sign-in. Return to Daily Focus and try again.'; });
</script></html>''';
