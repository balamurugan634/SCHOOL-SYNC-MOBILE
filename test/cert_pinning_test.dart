import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/network/cert_pinning.dart';

// Generated with openssl; the expected pins come from
//   openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
const _rsaCert = 'MIIDHTCCAgWgAwIBAgIUakKjfR9VodttAos6WyddrpbErOYwDQYJKoZIhvcNAQELBQAwHjEcMBoGA1UEAwwTdGVzdC5zY2hvb2xzeW5jLmFwcDAeFw0yNjEwMjExMzIxMjZaFw0zNjEwMTgxMzIxMjZaMB4xHDAaBgNVBAMME3Rlc3Quc2Nob29sc3luYy5hcHAwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCtanPHHwbBdUSZfX6KDmaIo/HDBv8/CHVXalr0DJDIL5Khg/x7kqAoaB4kKnMUummkuo6gVu2g2x5+9mXc9m/Sd2KBX0956NklXw1v5S9ZGULIDzfOt2NhAOGRkObgv1xQh++rXfx8OPj0CxO8dFoCqhmzf58HwWk5AZNVDb5H15J8OrhsEtrnaEFuFt1gddHAhdrRMG+CZ94+p3w2+vq2Ed/sw9+8oI/fCb7LvhunoO+GTAzCWBjCAhkYk3QtVyahSuZw31pWJhPv032WlWCLEN2wldSp/HO+wfKstXP1EJ53lrBc9zYUTz6ePor2LyDkohTmUkGgVHjDOxydggSXAgMBAAGjUzBRMB0GA1UdDgQWBBRc+o2aLxaaxob3/HuqdnueuyZ8wTAfBgNVHSMEGDAWgBRc+o2aLxaaxob3/HuqdnueuyZ8wTAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQAD0A08r0hEYZ6lkRfjtucZlybTySDbmBR/EQTTmdo2v4cJ8ZjOejSp3SpSFjFSHi6C6nBs7r1jlAX5aQejs0mZoRMpGvBLYSCMEpdOaOV5XanKbYxAsLGtsAATz0jJ07jvsYEBcInJtsdpgeCJrN6swNavipe/otBIf2A/vbHcl8ir1cgfkVqvEBEaCiL4oXM1xzhhiidMhmM5Z8lGKw/KecG42hRFa4K6xJx1AKGNjqTkJMkT8LjwtKEKCOZzQalZrvvJWlUpFJizO2os5j0q7IQCfC6GYtDEq7sbdBTTpMUA3w5NUUd7jJRrjiQtauyPMK8pIyDgp98o04Rkk7E9';
const _rsaPin = 'pyWXxcGEcVWaPphVO5vkLpVlYyHD5VoUQe5Hk5R1GgY=';
const _ecCert = 'MIIBjTCCATOgAwIBAgIUauxt+mknyiKC+TApB6Eb29vmi/AwCgYIKoZIzj0EAwIwHDEaMBgGA1UEAwwRZWMuc2Nob29sc3luYy5hcHAwHhcNMjYxMDIxMTMyMTI2WhcNMzYxMDE4MTMyMTI2WjAcMRowGAYDVQQDDBFlYy5zY2hvb2xzeW5jLmFwcDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABC4Qugi9HPtDG0jh3xYGHHXh64wlpktpcejAmz4Qdqy2WDbID0D4YR5TSLpjh9a8+xP3xV97mzMt9b+Smd/rkWajUzBRMB0GA1UdDgQWBBRe0vxQVvrcn8TzdtSXgZe9PsXb/jAfBgNVHSMEGDAWgBRe0vxQVvrcn8TzdtSXgZe9PsXb/jAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0gAMEUCIBJY5DVIrFFdhqaYW/qvjxX7CKQueMnRXTZA4VrZ8WN8AiEApgm2ruUS93mtDdlH/a4KKDgt9TU363MDo/7cYe5STdM=';
const _ecPin = 'eEIZw0fiCSp2VYZ4+ldJHX34ldB/UxdjNe2tBNLyOW0=';

void main() {
  test('SPKI pin of an RSA certificate matches openssl', () {
    expect(spkiSha256(base64.decode(_rsaCert)), _rsaPin);
  });

  test('SPKI pin of an EC certificate matches openssl', () {
    expect(spkiSha256(base64.decode(_ecCert)), _ecPin);
  });

  test('garbage is rejected instead of pinning something wrong', () {
    expect(() => spkiSha256(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    expect(() => spkiSha256(Uint8List(0)), throwsFormatException);
  });
}
