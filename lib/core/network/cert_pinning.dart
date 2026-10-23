import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Extracts the DER-encoded SubjectPublicKeyInfo from a DER X.509 certificate.
///
/// Certificate ::= SEQUENCE { tbsCertificate SEQUENCE { [0] version OPTIONAL,
/// serial, signature, issuer, validity, subject, subjectPublicKeyInfo, ... } ... }
Uint8List extractSpki(Uint8List der) {
  final cert = _readTlv(der, 0);
  final tbs = _readTlv(der, cert.valueStart);
  var i = tbs.valueStart;
  var first = _readTlv(der, i);
  if (first.tag == 0xA0) {
    i = first.end; // skip explicit version
  }
  // serial, signature algorithm, issuer, validity, subject
  for (var skip = 0; skip < 5; skip++) {
    i = _readTlv(der, i).end;
  }
  final spki = _readTlv(der, i);
  return Uint8List.sublistView(der, spki.start, spki.end);
}

/// base64(SHA-256(SPKI)) — the same format as HPKP / OkHttp pins and
/// `openssl x509 -pubkey | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64`.
String spkiSha256(Uint8List certDer) => base64.encode(sha256.convert(extractSpki(certDer)).bytes);

class _Tlv {
  const _Tlv(this.tag, this.start, this.valueStart, this.end);
  final int tag;
  final int start;
  final int valueStart;
  final int end;
}

_Tlv _readTlv(Uint8List d, int offset) {
  if (offset + 2 > d.length) throw const FormatException('Truncated DER');
  final tag = d[offset];
  final lenByte = d[offset + 1];
  int length;
  int valueStart;
  if (lenByte & 0x80 == 0) {
    length = lenByte;
    valueStart = offset + 2;
  } else {
    final n = lenByte & 0x7f;
    if (n == 0 || n > 4 || offset + 2 + n > d.length) throw const FormatException('Bad DER length');
    length = 0;
    for (var k = 0; k < n; k++) {
      length = (length << 8) | d[offset + 2 + k];
    }
    valueStart = offset + 2 + n;
  }
  final end = valueStart + length;
  if (end > d.length) throw const FormatException('Truncated DER');
  return _Tlv(tag, offset, valueStart, end);
}

/// Pins connections to hosts under [hostSuffixes] to a known server public key.
///
/// A pinned connection trusts *only* the pinned key: the trust store is empty so
/// every certificate is reported as "bad", and [IOHttpClientAdapter] only lets
/// the TLS handshake finish when the leaf SPKI matches one of [pins] and the
/// certificate is currently valid. Because the handshake itself proves
/// possession of the private key, this is sound and nothing is sent to an
/// impostor. Other hosts use the normal system trust store.
class PinningAdapter implements HttpClientAdapter {
  PinningAdapter({required this.pins, required this.hostSuffixes, HttpClientAdapter? fallback})
    : _fallback = fallback ?? IOHttpClientAdapter(),
      _pinned = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient(context: SecurityContext(withTrustedRoots: false));
          client.badCertificateCallback = (X509Certificate cert, String host, int port) {
            final now = DateTime.now();
            if (now.isBefore(cert.startValidity) || now.isAfter(cert.endValidity)) return false;
            try {
              return pins.contains(spkiSha256(cert.der));
            } catch (_) {
              return false;
            }
          };
          return client;
        },
      );

  final List<String> pins;
  final List<String> hostSuffixes;
  final HttpClientAdapter _fallback;
  final HttpClientAdapter _pinned;

  bool _isPinnedHost(String host) {
    final h = host.toLowerCase();
    return hostSuffixes.any((s) => h == s || h.endsWith('.$s'));
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    final adapter = _isPinnedHost(options.uri.host) ? _pinned : _fallback;
    return adapter.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    _pinned.close(force: force);
    _fallback.close(force: force);
  }
}
