import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:devhub/src/core/config.dart';

class R2Uploader {
  R2Uploader(this.config);

  final R2Config config;

  static const String _region = 'auto';
  static const String _service = 's3';

  Future<String> upload(File file, String key, {DateTime? now}) async {
    final bytes = await file.readAsBytes();
    final t = (now ?? DateTime.now()).toUtc();
    final amzDate = amzTimestamp(t);
    final dateStamp = amzDate.substring(0, 8);
    final host = config.host;
    final canonicalUri = '/${config.bucket}/$key';
    final payloadHash = sha256.convert(bytes).toString();

    const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
    final canonicalHeaders = 'host:$host\n'
        'x-amz-content-sha256:$payloadHash\n'
        'x-amz-date:$amzDate\n';
    final canonicalRequest = [
      'PUT',
      canonicalUri,
      '',
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final scope = '$dateStamp/$_region/$_service/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final key0 = signingKey(
      config.secretAccessKey,
      dateStamp,
      _region,
      _service,
    );
    final signature =
        Hmac(sha256, key0).convert(utf8.encode(stringToSign)).toString();
    final authorization =
        'AWS4-HMAC-SHA256 Credential=${config.accessKeyId}/$scope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';

    final client = HttpClient();
    try {
      final req = await client.putUrl(Uri.https(host, canonicalUri));
      req.headers
        ..set('x-amz-date', amzDate)
        ..set('x-amz-content-sha256', payloadHash)
        ..set('authorization', authorization)
        ..contentLength = bytes.length;
      req.add(bytes);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('R2 PUT ${resp.statusCode}: ${tail(body)}');
      }
    } finally {
      client.close();
    }

    final base = config.publicBaseUrl;
    if (base != null && base.isNotEmpty) {
      return '${base.replaceAll(RegExp(r'/+$'), '')}/$key';
    }
    return 'r2://${config.bucket}/$key';
  }

  static List<int> signingKey(
    String secret,
    String dateStamp,
    String region,
    String service,
  ) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$secret'))
        .convert(utf8.encode(dateStamp))
        .bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    return Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
  }

  static String amzTimestamp(DateTime utc) {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = utc;
    return '${d.year}${two(d.month)}${two(d.day)}T'
        '${two(d.hour)}${two(d.minute)}${two(d.second)}Z';
  }

  static String tail(String s, [int n = 200]) =>
      s.length <= n ? s : s.substring(s.length - n);
}
