/// Free-tier caps used until lifetime Pro is purchased.
///
/// Pro removes these limits. Values are product rules, not
/// UI-only hints — [GameLibrary] and shell screens enforce the same numbers.
abstract final class FreeLimits {
  /// Max games that may have a custom tile (avatar) image.
  static const int maxAvatars = 2;

  /// Max games that may have a custom cover / backdrop image.
  static const int maxCovers = 2;

  /// Max user groups in the library.
  static const int maxGroups = 1;
}

/// Canonical free-tier copy (library throws; UI toasts the same strings).
abstract final class FreeTierMessages {
  static String get avatars =>
      'Free plan allows ${FreeLimits.maxAvatars} tile images. '
      'Upgrade to Pro for unlimited.';

  static String get covers =>
      'Free plan allows ${FreeLimits.maxCovers} cover image. '
      'Upgrade to Pro for unlimited.';

  static String get groups =>
      'Free plan allows ${FreeLimits.maxGroups} group. '
      'Upgrade to Pro for unlimited groups.';

  static const String multiBackup =
      'Multi pack export & import require Pro. Upgrade to unlock.';
}

/// Thrown when a free-tier cap is hit (UI maps this to a toast / upsell).
class FreeTierLimitException implements Exception {
  const FreeTierLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}
