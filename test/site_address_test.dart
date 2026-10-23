import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/util/app_version.dart';
import 'package:schoolsync/core/util/site_address.dart';

SiteAddress parse(String s, {String devApi = '', bool insecure = false}) =>
    normalizeSiteInput(s, baseDomain: 'schoolsync.app', devApi: devApi, allowInsecure: insecure);

void main() {
  group('normalizeSiteInput', () {
    test('expands a school code to https://<code>.<baseDomain>', () {
      final a = parse('greenvalley');
      expect(a.baseUrl, 'https://greenvalley.schoolsync.app');
      expect(a.tenantCode, isNull);
    });

    test('code is case-insensitive and trimmed', () {
      expect(parse('  GreenValley ').baseUrl, 'https://greenvalley.schoolsync.app');
    });

    test('accepts a full URL and keeps only the origin', () {
      expect(parse('https://greenvalley.schoolsync.app/some/path?x=1#f').baseUrl, 'https://greenvalley.schoolsync.app');
      expect(parse('HTTPS://GreenValley.SchoolSync.App/').baseUrl, 'https://greenvalley.schoolsync.app');
    });

    test('a bare host gets https', () {
      expect(parse('greenvalley.schoolsync.app').baseUrl, 'https://greenvalley.schoolsync.app');
      expect(parse('erp.myschool.edu').baseUrl, 'https://erp.myschool.edu');
    });

    test('keeps a non-default port, drops the default one', () {
      expect(parse('https://erp.myschool.edu:8443').baseUrl, 'https://erp.myschool.edu:8443');
      expect(parse('https://erp.myschool.edu:443').baseUrl, 'https://erp.myschool.edu');
    });

    test('DEV_API sends every code to that API as X-Tenant', () {
      final a = parse('demo', devApi: 'http://10.0.2.2:4000');
      expect(a.baseUrl, 'http://10.0.2.2:4000');
      expect(a.tenantCode, 'demo');
    });

    test('rejects http:// when insecure addresses are not allowed (release)', () {
      expect(() => parse('http://greenvalley.schoolsync.app'), throwsA(_problem(SiteInputProblem.insecure)));
      expect(() => parse('localhost:4000'), throwsA(_problem(SiteInputProblem.insecure)));
      expect(() => parse('192.168.1.5'), throwsA(_problem(SiteInputProblem.insecure)));
    });

    test('allows http:// and local hosts in debug', () {
      expect(parse('http://192.168.1.20:4000', insecure: true).baseUrl, 'http://192.168.1.20:4000');
      expect(parse('localhost:4000', insecure: true).baseUrl, 'https://localhost:4000');
    });

    test('rejects empty, bad codes, other schemes and junk', () {
      expect(() => parse('   '), throwsA(_problem(SiteInputProblem.empty)));
      expect(() => parse('ab'), throwsA(_problem(SiteInputProblem.badCode)));
      expect(() => parse('1green'), throwsA(_problem(SiteInputProblem.badCode)));
      expect(() => parse('green_valley'), throwsA(_problem(SiteInputProblem.badCode)));
      expect(() => parse('ftp://greenvalley.schoolsync.app'), throwsA(_problem(SiteInputProblem.unsupportedScheme)));
      expect(() => parse('javascript:alert(1)'), throwsA(isA<SiteInputException>()));
      expect(() => parse('https://user:pw@greenvalley.schoolsync.app'), throwsA(_problem(SiteInputProblem.badUrl)));
      expect(() => parse('https://exa mple.com'), throwsA(_problem(SiteInputProblem.badUrl)));
      expect(() => parse('https://-bad-.com'), throwsA(_problem(SiteInputProblem.badUrl)));
    });

    test('withTenant keeps the base url and records the authoritative code', () {
      final a = parse('https://greenvalley.schoolsync.app').withTenant('greenvalley');
      expect(a.tenantCode, 'greenvalley');
      expect(SiteAddress.fromJson(a.toJson()), a);
    });
  });

  group('normalizeDevApi', () {
    test('adds http:// and strips the path', () {
      expect(normalizeDevApi('192.168.1.20:4000'), 'http://192.168.1.20:4000');
      expect(normalizeDevApi(' http://10.0.2.2:4000/api/v1 '), 'http://10.0.2.2:4000');
    });
    test('blank means "none", junk means null', () {
      expect(normalizeDevApi(''), '');
      expect(normalizeDevApi('ht tp://x'), isNull);
      expect(normalizeDevApi('ftp://x.com'), isNull);
      expect(normalizeDevApi('http://'), isNull);
    });
  });

  group('compareVersions', () {
    test('orders dotted versions numerically', () {
      expect(compareVersions('1.2.10', '1.2.9'), 1);
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('0.9.9', '1.0.0'), -1);
      expect(compareVersions('2.0.0-beta+4', '2.0.0'), 0);
    });
    test('isBelowMinimum', () {
      expect(isBelowMinimum('1.0.0', '1.1.0'), isTrue);
      expect(isBelowMinimum('1.1.0', '1.1.0'), isFalse);
      expect(isBelowMinimum('1.0.0', '0.0.0'), isFalse);
    });
  });
}

Matcher _problem(SiteInputProblem p) => isA<SiteInputException>().having((e) => e.problem, 'problem', p);
