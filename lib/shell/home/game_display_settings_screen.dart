import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/entitlements/free_limits.dart';
import '../../models/library_game.dart';
import '../../infrastructure/library/game_library.dart';
import '../theme/home_tokens.dart';
import '../common/app_toast.dart';
import '../common/console_chrome.dart';
import '../common/shell_art.dart';
import '../common/shell_art_warmer.dart';
import '../common/shell_file_image.dart';
import '../common/shell_page_header.dart';

/// Long-press destination: name, description, avatar + cover art, groups.
class GameDisplaySettingsScreen extends StatefulWidget {
  const GameDisplaySettingsScreen({
    super.key,
    required this.library,
    required this.gameId,
    this.onRemove,
  });

  final GameLibrary library;
  final String gameId;

  /// Optional remove handler (home can pass confirm flow).
  final Future<void> Function(LibraryGame game)? onRemove;

  @override
  State<GameDisplaySettingsScreen> createState() =>
      _GameDisplaySettingsScreenState();
}

/// Tile image vs backdrop banner — mirrors library avatar/cover axis.
enum _ArtSlot { tile, backdrop }

class _GameDisplaySettingsScreenState extends State<GameDisplaySettingsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;
  /// Slots currently running copy / clear / thumb work (parallel ok).
  final Set<_ArtSlot> _artBusy = {};

  LibraryGame? get _game => widget.library.byId(widget.gameId);

  bool _isArtBusy(_ArtSlot slot) => _artBusy.contains(slot);

  @override
  void initState() {
    super.initState();
    final g = _game;
    _nameCtrl = TextEditingController(text: g?.displayName ?? '');
    _descCtrl = TextEditingController(text: g?.description ?? '');
    widget.library.addListener(_onLibrary);
  }

  void _onLibrary() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    widget.library.removeListener(_onLibrary);
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// Drop IME focus before the route animates out — avoids a one-frame
  /// yellow overflow stripe while the keyboard inset collapses mid-pop.
  void _unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _saveText() async {
    final g = _game;
    if (g == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.library.updateDisplayInfo(
        g.id,
        displayName: _nameCtrl.text,
        description: _descCtrl.text,
      );
      if (!mounted) return;
      _unfocus();
      AppToast.success(context, 'Saved');
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.error(context, e.toString());
      }
    }
  }

  String? _fileName(LibraryGame g, _ArtSlot slot) => switch (slot) {
        _ArtSlot.tile => g.avatarFileName,
        _ArtSlot.backdrop => g.coverFileName,
      };

  String? _paintPath(LibraryGame g, _ArtSlot slot) => switch (slot) {
        _ArtSlot.tile => widget.library.avatarAbsolutePath(g),
        _ArtSlot.backdrop => widget.library.coverAbsolutePath(g),
      };

  int _formCachePx(BuildContext context, _ArtSlot slot) => switch (slot) {
        _ArtSlot.tile => ShellArt.formAvatarCachePx(context),
        _ArtSlot.backdrop => ShellArt.formCoverCachePx(context),
      };

  void _invalidateArtPaths(Iterable<String> paths) {
    for (final path in paths) {
      ShellFileImage.evictPath(path);
      ShellArtWarmer.invalidatePath(path);
    }
  }

  Future<void> _warmFormArt(_ArtSlot slot, LibraryGame game) async {
    final path = _paintPath(game, slot);
    if (path == null || !mounted) return;
    await ShellFileImage.precache(
      context,
      path,
      memCacheWidth: _formCachePx(context, slot),
    );
  }

  /// Shell owns the image picker; library only accepts paths.
  Future<String?> _pickImagePath() async {
    final file = await FilePicker.pickFile(
      type: FileType.image,
      dialogTitle: 'Select image',
    );
    return file?.path;
  }

  Future<void> _runArtOp(
    _ArtSlot slot, {
    required Future<void> Function(LibraryGame g) mutate,
    bool warmAfter = false,
  }) async {
    final g = _game;
    if (g == null || _isArtBusy(slot)) return;

    final prevName = _fileName(g, slot);
    final stale = widget.library.artPathsForFileName(prevName);

    setState(() => _artBusy.add(slot));
    try {
      await mutate(g);
      final next = _game;
      if (next == null) return;
      if (_fileName(next, slot) != prevName) {
        _invalidateArtPaths(stale);
      }
      if (warmAfter && mounted) {
        await _warmFormArt(slot, next);
      }
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _artBusy.remove(slot));
    }
  }

  Future<void> _pickArt(_ArtSlot slot) async {
    final g = _game;
    if (g == null || _isArtBusy(slot)) return;

    final allowed = switch (slot) {
      _ArtSlot.tile => widget.library.canSetAvatar(g.id),
      _ArtSlot.backdrop => widget.library.canSetCover(g.id),
    };
    if (!allowed) {
      AppToast.error(
        context,
        switch (slot) {
          _ArtSlot.tile => FreeTierMessages.avatars,
          _ArtSlot.backdrop => FreeTierMessages.covers,
        },
      );
      return;
    }

    final path = await _pickImagePath();
    if (path == null || !mounted) return;

    await _runArtOp(
      slot,
      warmAfter: true,
      mutate: (game) => switch (slot) {
        _ArtSlot.tile => widget.library.setAvatarFromPath(game.id, path),
        _ArtSlot.backdrop => widget.library.setCoverFromPath(game.id, path),
      },
    );
  }

  Future<void> _clearArt(_ArtSlot slot) async {
    await _runArtOp(
      slot,
      mutate: (game) => switch (slot) {
        _ArtSlot.tile => widget.library.clearAvatar(game.id),
        _ArtSlot.backdrop => widget.library.clearCover(game.id),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    if (g == null) {
      return Scaffold(
        backgroundColor: HomeColors.bg,
        body: ConsoleChrome(
          child: Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Game removed'),
            ),
          ),
        ),
      );
    }

    final avatar = widget.library.avatarAbsolutePath(g);
    final cover = widget.library.coverAbsolutePath(g);
    final hasAvatar = avatar != null && avatar.isNotEmpty;
    final hasCover = cover != null && cover.isNotEmpty;
    final avatarCache = ShellArt.formAvatarCachePx(context);
    final coverCache = ShellArt.formCoverCachePx(context);

    // IME open: Scaffold already shrinks body by viewInsets. Extra bottom pad
    // (or leftover viewPadding) shows as a solid black strip above the keyboard.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final imeOpen = keyboard > 0;
    final contentPad = HomeSpacing.formContentPadFor(imeOpen: imeOpen);

    // Drop bottom viewPadding while IME is up so nothing re-applies the
    // system-nav inset on top of Scaffold’s keyboard resize.
    final mq = MediaQuery.of(context);
    final bodyMq = imeOpen
        ? mq.copyWith(
            viewPadding: mq.viewPadding.copyWith(bottom: 0),
            padding: mq.padding.copyWith(bottom: 0),
          )
        : mq;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        _unfocus();
      },
      child: Scaffold(
        backgroundColor: HomeColors.bg,
        resizeToAvoidBottomInset: true,
        body: MediaQuery(
          data: bodyMq,
          child: ConsoleChrome(
            // Never reserve system-nav height here — with IME that becomes a
            // second black band stacked above the keyboard.
            bottom: false,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShellPageHeader(
                title: 'Game display',
                onBack: () {
                  _unfocus();
                  Navigator.maybePop(context);
                },
                trailing: TextButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          _unfocus();
                          await _saveText();
                        },
                  child: SizedBox(
                    width: HomeSizes.formSaveSlotW,
                    height: HomeSizes.formSaveSlotH,
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: HomeSizes.formSaveSpinner,
                              height: HomeSizes.formSaveSpinner,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: HomeColors.lemon,
                              ),
                            )
                          : const Text(
                              'Save',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                fontSize: HomeSizes.formBodySize,
                                color: HomeColors.lemon,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: contentPad,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Left: art + description ──────────────────────────
                      Expanded(
                        child: ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          // Tiny air when IME open so the focused field can
                          // scroll flush to the keyboard top (no fat black pad).
                          padding: EdgeInsets.only(
                            bottom: imeOpen ? HomeSpacing.sm : 0,
                          ),
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ArtPickerCard(
                                  hint: 'Tile',
                                  width: HomeSizes.formAvatarSize,
                                  height: HomeSizes.formAvatarSize,
                                  busy: _isArtBusy(_ArtSlot.tile),
                                  onTap: () => _pickArt(_ArtSlot.tile),
                                  onClear: hasAvatar
                                      ? () => _clearArt(_ArtSlot.tile)
                                      : null,
                                  child: ShellCoverImage(
                                    path: avatar,
                                    memCacheWidth: avatarCache,
                                    underColor: HomeColors.bg,
                                    placeholder: ShellArtPlaceholder(
                                      monogram: g.monogram,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: HomeSpacing.formArtGap),
                                Expanded(
                                  child: _ArtPickerCard(
                                    hint: 'Backdrop',
                                    width: double.infinity,
                                    height: HomeSizes.formCoverHeight,
                                    busy: _isArtBusy(_ArtSlot.backdrop),
                                    onTap: () => _pickArt(_ArtSlot.backdrop),
                                    onClear: hasCover
                                        ? () => _clearArt(_ArtSlot.backdrop)
                                        : null,
                                    child: ShellCoverImage(
                                      path: cover,
                                      memCacheWidth: coverCache,
                                      underColor: HomeColors.bg,
                                      placeholder: const ShellArtPlaceholder(
                                        label: 'Cover',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Same-column stack — not a section break.
                            const SizedBox(height: HomeSpacing.formStackGap),
                            TextField(
                              controller: _nameCtrl,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: HomeSizes.formBodySize,
                                color: HomeColors.labelOn,
                              ),
                              decoration: _fieldDeco(hint: 'Name'),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: HomeSpacing.formStackGap),
                            TextField(
                              controller: _descCtrl,
                              minLines: 3,
                              maxLines: 6,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: HomeSizes.formBodySize,
                                color: HomeColors.labelOn,
                              ),
                              decoration: _fieldDeco(hint: 'Description'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: HomeSpacing.formColGap),
                      // ── Right: groups scroll; remove stays pinned ────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ListView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.only(
                                  bottom: imeOpen ? HomeSpacing.sm : 0,
                                ),
                                children: [
                                  _GroupsSection(
                                    library: widget.library,
                                    gameId: g.id,
                                  ),
                                ],
                              ),
                            ),
                            if (widget.onRemove != null) ...[
                              const SizedBox(
                                height: HomeSpacing.formSectionGap,
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  _unfocus();
                                  await widget.onRemove!(g);
                                  if (context.mounted &&
                                      widget.library.byId(g.id) == null) {
                                    Navigator.pop(context);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: HomeColors.missing,
                                  side: BorderSide(
                                    color: HomeColors.missing
                                        .withValues(alpha: 0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      HomeSizes.formRadius,
                                    ),
                                  ),
                                ),
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedDelete02,
                                  size: 18,
                                  color: HomeColors.missing,
                                ),
                                label: const Text(
                                  'Delete all',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w700,
                                    fontSize: HomeSizes.formBodySize,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco({required String hint}) {
    final r = BorderRadius.circular(HomeSizes.formRadius);
    return InputDecoration(
      // Hint only — no floating label on the frame.
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: HomeSizes.formBodySize,
        color: HomeColors.labelDim,
      ),
      isDense: true,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: HomeSpacing.md,
        vertical: HomeSpacing.md,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: const BorderSide(color: HomeColors.tileBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: const BorderSide(color: HomeColors.lemon, width: 1.5),
      ),
    );
  }
}

/// Toggle which library groups contain this game.
class _GroupsSection extends StatelessWidget {
  const _GroupsSection({required this.library, required this.gameId});

  final GameLibrary library;
  final String gameId;

  @override
  Widget build(BuildContext context) {
    final groups = library.groups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Same section chrome as Settings hub.
        const Text(
          'GROUPS',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: HomeSizes.sectionLabelSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: HomeColors.labelDim,
          ),
        ),
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              HomeSpacing.sm,
              HomeSpacing.sm,
              HomeSpacing.sm,
              0,
            ),
            child: Text(
              'Create groups on the All games screen to organize titles.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: HomeSizes.formHintSize,
                color: HomeColors.labelDim,
                height: 1.35,
              ),
            ),
          )
        else ...[
          const SizedBox(height: HomeSpacing.sm),
          for (final group in groups)
            _GroupCheckRow(
              name: group.name,
              selected: group.gameIds.contains(gameId),
              onChanged: (v) async {
                try {
                  final next = library
                      .groupsForGame(gameId)
                      .map((g) => g.id)
                      .toSet();
                  if (v) {
                    next.add(group.id);
                  } else {
                    next.remove(group.id);
                  }
                  await library.setGroupsForGame(gameId, next);
                } catch (e) {
                  if (context.mounted) {
                    AppToast.error(context, e.toString());
                  }
                }
              },
            ),
        ],
      ],
    );
  }
}

/// Flat check row — ListTile density like Settings.
class _GroupCheckRow extends StatelessWidget {
  const _GroupCheckRow({
    required this.name,
    required this.selected,
    required this.onChanged,
  });

  final String name;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: HomeSpacing.sm,
        vertical: HomeSpacing.xs,
      ),
      leading: Container(
        width: HomeSizes.sheetCheckSize,
        height: HomeSizes.sheetCheckSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? HomeColors.lemon : Colors.transparent,
          border: Border.all(
            color: selected ? HomeColors.lemon : HomeColors.tileBorder,
            width: 1.5,
          ),
        ),
        child: selected
            ? const Icon(
                Icons.check_rounded,
                size: HomeSizes.sheetCheckIconSize,
                color: HomeColors.onLemon,
              )
            : null,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
          fontSize: HomeSizes.formBodySize,
          color: selected ? HomeColors.lemon : HomeColors.labelOn,
        ),
      ),
      onTap: () => onChanged(!selected),
    );
  }
}

class _ArtPickerCard extends StatelessWidget {
  const _ArtPickerCard({
    required this.hint,
    required this.width,
    required this.height,
    required this.onTap,
    required this.child,
    this.busy = false,
    this.onClear,
  });

  final String hint;
  final double width;
  final double height;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final Widget child;
  /// Copy + thumbnail pipeline after the system picker returns.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HomeSizes.tileRadius);
    return SizedBox(
      width: width == double.infinity ? null : width,
      height: height,
      child: Material(
        // No gray fill — transparent on black + thin border (Settings language).
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: HomeColors.tileBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              Positioned(
                left: HomeSpacing.sm,
                right: HomeSpacing.sm,
                bottom: HomeSpacing.sm,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HomeSpacing.sm,
                      vertical: HomeSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: HomeColors.inkScrim,
                      borderRadius: BorderRadius.circular(HomeSpacing.sm),
                    ),
                    child: Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: HomeSizes.formBadgeSize,
                        color: HomeColors.cream,
                      ),
                    ),
                  ),
                ),
              ),
              if (onClear != null && !busy)
                Positioned(
                  top: HomeSpacing.xs,
                  right: HomeSpacing.xs,
                  child: IconButton(
                    tooltip: 'Remove image',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: HomeColors.inkScrim,
                    ),
                    onPressed: onClear,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: HomeSizes.formHintSize + 4,
                      color: HomeColors.cream,
                    ),
                  ),
                ),
              if (busy)
                const ColoredBox(
                  color: HomeColors.artScrim,
                  child: Center(
                    child: SizedBox(
                      width: HomeSizes.formArtSpinner,
                      height: HomeSizes.formArtSpinner,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: HomeColors.lemon,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

