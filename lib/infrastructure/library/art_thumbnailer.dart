import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Disk thumbnails for library art (tile + backdrop).
///
/// Source files may be multi‑megabyte camera/export images. Tiles and the home
/// backdrop always paint **these** PNGs so cold open / scroll never re-decode
/// full-resolution originals.
abstract final class ArtThumbnailer {
  /// Max edge (px) for shelf / library tiles.
  ///
  /// Sized for large shelf tiles on high-DPR screens (e.g. 168 logical × 3.5
  /// ≈ 588). 512 left slight softness; 768 keeps headroom without heavy RAM.
  static const int tileMaxEdge = 768;

  /// Max edge for full-bleed home blur backdrop.
  static const int backdropMaxEdge = 1280;

  /// Longer side in px, or null if unreadable.
  static Future<int?> longerEdge(File file) async {
    if (!await file.exists()) return null;
    Uint8List raw;
    try {
      raw = await file.readAsBytes();
    } catch (_) {
      return null;
    }
    if (raw.isEmpty) return null;

    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(raw);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      if (w < 1 || h < 1) return null;
      return w >= h ? w : h;
    } catch (_) {
      return null;
    } finally {
      codec?.dispose();
    }
  }

  /// True when [thumb] is missing or clearly below the size we would write
  /// from [source] at [maxEdge] (e.g. old 512px tiles after a max-edge bump).
  static Future<bool> needsRewrite({
    required File source,
    required File thumb,
    required int maxEdge,
  }) async {
    if (!await thumb.exists()) return true;
    final thumbEdge = await longerEdge(thumb);
    if (thumbEdge == null) return true;
    // Already at/near current max — skip reading the (often huge) original.
    if (thumbEdge + 16 >= maxEdge) return false;
    final srcEdge = await longerEdge(source);
    if (srcEdge == null) return false;
    final target = srcEdge < maxEdge ? srcEdge : maxEdge;
    // Slack for codec rounding; rewrite when undersized vs intended target.
    return thumbEdge + 16 < target;
  }

  /// Decode [source], scale so the longer side ≤ [maxEdge], write PNG to [dest].
  static Future<bool> writeResizedPng({
    required File source,
    required File dest,
    required int maxEdge,
  }) async {
    if (maxEdge < 1) return false;
    if (!await source.exists()) return false;

    final Uint8List raw;
    try {
      raw = await source.readAsBytes();
    } catch (_) {
      return false;
    }
    if (raw.isEmpty) return false;

    ui.Codec? codec;
    ui.Image? image;
    try {
      // Probe dimensions.
      codec = await ui.instantiateImageCodec(raw);
      final probe = await codec.getNextFrame();
      final srcW = probe.image.width;
      final srcH = probe.image.height;
      probe.image.dispose();
      codec.dispose();
      codec = null;

      if (srcW < 1 || srcH < 1) return false;

      final longer = srcW >= srcH ? srcW : srcH;
      if (longer <= maxEdge) {
        codec = await ui.instantiateImageCodec(raw);
      } else if (srcW >= srcH) {
        codec = await ui.instantiateImageCodec(raw, targetWidth: maxEdge);
      } else {
        codec = await ui.instantiateImageCodec(raw, targetHeight: maxEdge);
      }

      final frame = await codec.getNextFrame();
      image = frame.image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return false;

      await dest.parent.create(recursive: true);
      final tmp = File('${dest.path}.tmp');
      await tmp.writeAsBytes(png.buffer.asUint8List(), flush: true);
      if (await dest.exists()) {
        try {
          await dest.delete();
        } catch (_) {}
      }
      await tmp.rename(dest.path);
      return true;
    } catch (_) {
      return false;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  static Future<bool> writeTileThumb({
    required File source,
    required File dest,
  }) =>
      writeResizedPng(source: source, dest: dest, maxEdge: tileMaxEdge);

  static Future<bool> writeBackdropThumb({
    required File source,
    required File dest,
  }) =>
      writeResizedPng(source: source, dest: dest, maxEdge: backdropMaxEdge);
}
