/// URLs supplied at build time with --dart-define-from-file.
abstract final class LegalUrls {
  static const String _base = String.fromEnvironment('LEGAL_BASE_URL');
  static const String _source = String.fromEnvironment('PROJECT_SOURCE_URL');

  static Uri? get privacyPolicy => _page('privacy');
  static Uri? get termsOfService => _page('terms');
  static Uri? get dataDeletion => _page('data-deletion');
  static Uri? get projectSource => _httpsUrl(_source);

  static Uri? _page(String path) {
    final base = _httpsUrl(_base);
    if (base == null) return null;
    return base.replace(path: '${base.path.replaceFirst(RegExp(r'/$'), '')}/$path/');
  }

  static Uri? _httpsUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri;
  }
}
