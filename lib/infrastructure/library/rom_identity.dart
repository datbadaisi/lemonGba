import 'dart:io';

import 'package:crypto/crypto.dart';

/// Stable identity for user-owned ROM data. File names are not unique enough
/// to safely key cartridge saves or save states.
class RomIdentity {
  const RomIdentity._(this.value);

  final String value;

  static Future<RomIdentity> fromFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return RomIdentity._(digest.toString());
  }
}
