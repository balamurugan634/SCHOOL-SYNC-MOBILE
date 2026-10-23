/// Dotted-number version comparison (`1.2.10 > 1.2.9`); pre-release and build
/// suffixes (`1.0.0-beta+4`) are ignored.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split(RegExp(r'[-+]'))
      .first
      .split('.')
      .map((p) => int.tryParse(p.trim()) ?? 0)
      .toList();
  final pa = parse(a), pb = parse(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

bool isBelowMinimum(String appVersion, String minVersion) => compareVersions(appVersion, minVersion) < 0;
