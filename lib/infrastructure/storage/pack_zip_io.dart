import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../core/storage/game_pack_port.dart';

/// One file member to place in a pack zip.
final class PackZipMember {
  const PackZipMember({required this.file, required this.zipPath});

  final File file;
  final String zipPath;

  PackZipMember withPrefix(String prefix) {
    final root = prefix.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    final rel = zipPath.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
    return PackZipMember(file: file, zipPath: '$root/$rel');
  }
}

/// Zip encode / extract helpers shared by pack services.
final class PackZipIo {
  PackZipIo(this.packsTempDir);

  final Directory packsTempDir;

  Future<GamePackExportResult> encodeZip({
    required GamePackKind kind,
    required String suggestedFileName,
    required Map<String, dynamic> manifest,
    required List<PackZipMember> members,
  }) async {
    await packsTempDir.create(recursive: true);
    final nonce = _nonce();
    final zipPath = p.join(packsTempDir.path, 'export_$nonce.zip');
    final manifestTemp = await writeTempText(
      'manifest_$nonce.json',
      const JsonEncoder.withIndent('  ').convert(manifest),
    );

    final encoder = ZipFileEncoder();
    try {
      encoder.create(zipPath);
      await encoder.addFile(manifestTemp, 'manifest.json');
      for (final m in members) {
        await encoder.addFile(m.file, m.zipPath);
      }
      await encoder.close();
    } catch (e) {
      try {
        await encoder.close();
      } catch (_) {}
      await deleteFileQuietly(File(zipPath));
      await deleteFileQuietly(manifestTemp);
      throw GamePackException(GamePackErrorCode.ioFailure, e.toString());
    }

    await deleteFileQuietly(manifestTemp);
    for (final m in members) {
      final base = p.basename(m.file.path);
      if (m.file.path.contains(p.join('tmp', 'packs')) &&
          (base.startsWith('library_entry') ||
              base.startsWith('game_manifest_'))) {
        await deleteFileQuietly(m.file);
      }
    }

    final len = await File(zipPath).length();
    return GamePackExportResult(
      tempFilePath: zipPath,
      suggestedFileName: suggestedFileName,
      byteLength: len,
      kind: kind,
    );
  }

  /// Decoded root object of the archive's root `manifest.json`.
  Future<Map<String, dynamic>> readManifestMap(String zipPath) async {
    final file = File(zipPath);
    if (!await file.exists()) {
      throw const GamePackException(
        GamePackErrorCode.invalidFormat,
        'Pack file not found',
      );
    }

    Archive archive;
    try {
      final bytes = await file.readAsBytes();
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const GamePackException(
        GamePackErrorCode.invalidFormat,
        'Could not read this Lemon pack',
      );
    }

    // Prefer exact root manifest over nested games/<id>/manifest.json.
    ArchiveFile? rootManifest;
    ArchiveFile? shallowest;
    var shallowestDepth = 1 << 30;
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = f.name.replaceAll('\\', '/');
      if (name == 'manifest.json' || name == './manifest.json') {
        rootManifest = f;
        break;
      }
      if (!name.endsWith('/manifest.json')) continue;
      final depth = name.split('/').where((s) => s.isNotEmpty).length;
      if (depth < shallowestDepth) {
        shallowestDepth = depth;
        shallowest = f;
      }
    }
    final manifestFile = rootManifest ?? shallowest;
    if (manifestFile == null) {
      throw const GamePackException(
        GamePackErrorCode.invalidFormat,
        'Missing manifest.json',
      );
    }

    try {
      final raw = utf8.decode(manifestFile.content);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('manifest root');
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw const GamePackException(
        GamePackErrorCode.invalidFormat,
        'Invalid manifest.json',
      );
    }
  }

  Future<Map<String, dynamic>> readManifestMapFromDir(Directory dir) async {
    final manifestFile = File(p.join(dir.path, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw const GamePackException(
        GamePackErrorCode.corruptEntry,
        'Missing per-game manifest.json',
      );
    }
    try {
      final decoded = jsonDecode(await manifestFile.readAsString());
      if (decoded is! Map) {
        throw const FormatException('manifest root');
      }
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      if (e is GamePackException) rethrow;
      throw const GamePackException(
        GamePackErrorCode.corruptEntry,
        'Invalid per-game manifest.json',
      );
    }
  }

  Future<Directory> extractZipToStage(String zipPath) async {
    await packsTempDir.create(recursive: true);
    final stage = Directory(
      p.join(packsTempDir.path, 'import_${_nonce()}'),
    );
    await stage.create(recursive: true);

    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = file.name.replaceAll('\\', '/');
        if (name.contains('..') || p.isAbsolute(name)) {
          throw const GamePackException(
            GamePackErrorCode.corruptEntry,
            'Unsafe path in pack',
          );
        }
        final outPath = p.join(stage.path, name);
        final outCanon = p.canonicalize(outPath);
        final stageCanon = p.canonicalize(stage.path);
        if (!outCanon.startsWith(stageCanon)) {
          throw const GamePackException(
            GamePackErrorCode.corruptEntry,
            'Zip-slip path rejected',
          );
        }
        await File(outPath).parent.create(recursive: true);
        await File(outPath).writeAsBytes(file.content, flush: true);
      }
    } catch (e) {
      await deleteDirQuietly(stage);
      if (e is GamePackException) rethrow;
      throw const GamePackException(
        GamePackErrorCode.invalidFormat,
        'Could not read this Lemon pack',
      );
    }
    return stage;
  }

  Future<File> writeTempText(String name, String text) async {
    await packsTempDir.create(recursive: true);
    final f = File(p.join(packsTempDir.path, name));
    await f.writeAsString(text, flush: true);
    return f;
  }

  String _nonce() {
    final r = Random.secure();
    final ms = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final n = r.nextInt(0xFFFFFF).toRadixString(16);
    return '${ms}_$n';
  }

  static Future<void> deleteFileQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<void> deleteDirQuietly(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
