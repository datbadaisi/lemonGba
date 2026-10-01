import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/entitlements/free_limits.dart';
import '../../core/storage/game_pack_port.dart';
import '../../infrastructure/library/game_library.dart';
import '../../models/library_game.dart';
import '../common/app_toast.dart';
import '../common/console_chrome.dart';
import '../common/shell_art.dart';
import '../common/shell_confirm_dialog.dart';
import '../common/shell_page_header.dart';
import '../common/shell_sheet.dart';
import '../theme/home_tokens.dart';
import 'game_pack_ui.dart';

/// Library-level multi export / import for save packs and full packs.
///
/// Opened from the home top bar (beside Settings). Free users may browse the
/// screen; export/import require Pro (service + UI gate).
class MultiBackupScreen extends StatefulWidget {
  const MultiBackupScreen({
    super.key,
    required this.packs,
    required this.library,
  });

  final GamePackPort packs;
  final GameLibrary library;

  @override
  State<MultiBackupScreen> createState() => _MultiBackupScreenState();
}

class _MultiBackupScreenState extends State<MultiBackupScreen> {
  final Set<String> _selected = {};
  final TextEditingController _search = TextEditingController();
  GamePackKind _kind = GamePackKind.saves;
  bool _busy = false;

  GameLibrary get _library => widget.library;

  bool get _isPro => _library.pro.isPro;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<LibraryGame> get _allGames => _library.gamesByRecent;

  List<LibraryGame> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _allGames;
    return _allGames
        .where((g) => g.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

  void _toggle(String id, bool on) {
    setState(() {
      if (on) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  void _selectAllVisible() {
    setState(() {
      for (final g in _filtered) {
        _selected.add(g.id);
      }
    });
  }

  void _clearSelection() {
    setState(_selected.clear);
  }

  /// Free users can preview UI; only export/import need Pro.
  bool _requirePro() {
    if (_isPro) return true;
    AppToast.error(context, FreeTierMessages.multiBackup);
    return false;
  }

  Future<void> _export() async {
    if (!_requirePro()) return;
    final ids = _selected.toList(growable: false);
    if (ids.isEmpty) {
      AppToast.error(context, 'Select at least one game');
      return;
    }

    final isFull = _kind == GamePackKind.full;
    final n = ids.length;
    await runGamePackExport(
      context: context,
      busy: _busy,
      setBusy: (v) => setState(() => _busy = v),
      workingMessage: isFull
          ? 'Exporting multi full pack…'
          : 'Exporting multi save pack…',
      successMessage:
          'Multi ${isFull ? 'full' : 'save'} pack exported '
          '($n ${n == 1 ? 'game' : 'games'})',
      failureMessage: 'Could not export multi pack',
      export: () => widget.packs.exportMultiPack(kind: _kind, gameIds: ids),
    );
  }

  Future<void> _importMulti() async {
    if (_busy) return;
    if (!_requirePro()) return;
    final path = await pickLemonPackPath(
      dialogTitle: 'Select multi Lemon pack',
    );
    if (path == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final inspected = await widget.packs.inspect(path);
      if (!mounted) return;

      if (inspected is! MultiPackInspect) {
        AppToast.error(context, 'Expected a multi Lemon pack');
        return;
      }
      final info = inspected.info;
      final n = info.gameCount;
      final kindLabel = info.kind == GamePackKind.full ? 'full' : 'save';
      final exported =
          info.exportedAt.toLocal().toString().split('.').first;

      if (info.kind == GamePackKind.saves) {
        final inLib =
            info.games.where((g) => _library.byId(g.gameId) != null).length;
        final missing = n - inLib;
        final ok = await showShellConfirmDialog(
          context,
          title: 'Import multi save pack?',
          message: missing > 0
              ? 'Restores progress for $inLib of $n games from $exported. '
                  '$missing not in your library will be skipped.'
              : 'Restores progress for $n ${n == 1 ? 'game' : 'games'} '
                  'from $exported. Existing saves will be replaced.',
          confirmLabel: 'Restore',
          destructive: true,
        );
        if (ok != true || !mounted) return;

        AppProgressToast.show(context, message: 'Importing multi save pack…');
        final result = await widget.packs.importMultiPack(path);
        if (!mounted) {
          AppProgressToast.dismiss();
          return;
        }
        _finishImportToast(result, kindLabel);
      } else {
        final replace =
            info.games.where((g) => _library.byId(g.gameId) != null).length;
        final create = n - replace;
        final parts = <String>[];
        if (create > 0) parts.add('$create new');
        if (replace > 0) parts.add('$replace replace');
        final ok = await showShellConfirmDialog(
          context,
          title: 'Import multi full pack?',
          message:
              'Applies $n ${n == 1 ? 'game' : 'games'} from $exported '
              '(${parts.join(', ')}). ROM, art, and progress for replaced '
              'titles will be overwritten. If the pack includes groups, they '
              'are merged with your local groups.\n\n'
              'Each game is applied independently — if one fails, others may '
              'still import.',
          confirmLabel: 'Import',
          destructive: replace > 0,
        );
        if (ok != true || !mounted) return;

        AppProgressToast.show(context, message: 'Importing multi full pack…');
        final result = await widget.packs.importMultiPack(path);
        if (!mounted) {
          AppProgressToast.dismiss();
          return;
        }
        _finishImportToast(result, kindLabel);
      }
    } on FreeTierLimitException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } on GamePackException catch (e) {
      if (mounted) AppToast.error(context, toastForGamePackError(e));
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not read this multi Lemon pack');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _finishImportToast(MultiGamePackImportResult result, String kindLabel) {
    if (result.imported == 0 && result.failed == 0) {
      AppProgressToast.completeError(
        context,
        result.skipped > 0
            ? 'No matching games in library to restore'
            : 'Nothing imported from multi $kindLabel pack',
      );
      return;
    }

    final g = result.groups;
    final bits = <String>[
      '${result.imported} imported',
      if (result.skipped > 0) '${result.skipped} skipped',
      if (result.failed > 0) '${result.failed} failed',
      if (g.created > 0) '${g.created} groups created',
      if (g.existingGroupsUpdated > 0) 'groups updated',
    ];

    // Prefer naming a single failure when useful.
    final failedEntries = result.entries
        .where((e) => e.status == MultiGamePackEntryStatus.failed)
        .toList();
    String? failDetail;
    if (failedEntries.length == 1) {
      final f = failedEntries.first;
      final name = (f.title != null && f.title!.isNotEmpty) ? f.title! : f.gameId;
      failDetail = f.errorMessage != null
          ? '$name: ${f.errorMessage}'
          : name;
    }

    if (result.failed > 0 && result.imported == 0) {
      AppProgressToast.completeError(
        context,
        failDetail != null
            ? 'Multi $kindLabel import failed — $failDetail'
            : 'Multi $kindLabel import failed (${bits.join(' · ')})',
      );
    } else {
      AppProgressToast.completeSuccess(
        context,
        'Multi $kindLabel pack · ${bits.join(' · ')}',
      );
      if (failDetail != null && result.imported > 0) {
        AppToast.error(context, 'Failed: $failDetail');
      }
    }

    if (result.anySkippedAvatar || result.anySkippedCover) {
      final parts = <String>[];
      if (result.anySkippedAvatar) parts.add('tile art');
      if (result.anySkippedCover) parts.add('cover');
      AppToast.error(
        context,
        'Some games imported without ${parts.join(' & ')} (free plan limit)',
      );
    }

    if (result.groups.skippedCreate > 0) {
      AppToast.error(
        context,
        'Some groups were not restored (free plan limit)',
      );
    }

    setState(() {
      _selected.removeWhere((id) => _library.byId(id) == null);
    });
  }

  String _exportLabel({
    required bool isPro,
    required bool isFull,
    required int selectedCount,
  }) {
    if (!isPro) return 'Export multi pack (Pro)';
    if (selectedCount == 0) return 'Export multi pack';
    return isFull
        ? 'Export multi full ($selectedCount)'
        : 'Export multi save ($selectedCount)';
  }

  @override
  Widget build(BuildContext context) {
    final games = _filtered;
    final selectedCount = _selected.length;
    final isFull = _kind == GamePackKind.full;
    final imeOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: HomeColors.bg,
      // Avoid double-inset: ConsoleChrome already pads; body resizes with IME.
      resizeToAvoidBottomInset: true,
      body: ConsoleChrome(
        bottom: false,
        child: AnimatedBuilder(
          animation: _library.pro,
          builder: (context, _) {
            final isPro = _library.pro.isPro;
            final exportLabel = _exportLabel(
              isPro: isPro,
              isFull: isFull,
              selectedCount: selectedCount,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShellPageHeader(
                  title: isPro ? 'Multi backup' : 'Multi backup · Pro',
                ),
                Expanded(
                  child: Padding(
                    padding: HomeSpacing.formContentPadFor(imeOpen: imeOpen),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Left: export / import (flat list like Settings) ──
                        Expanded(
                          child: ListView(
                            children: [
                              if (!isPro) ...[
                                const _ProPreviewBanner(),
                                const SizedBox(
                                  height: HomeSpacing.formSectionGap,
                                ),
                              ],
                              const _SectionLabel(label: 'Export'),
                              const SizedBox(height: HomeSpacing.sm),
                              _KindOption(
                                icon: HugeIcons.strokeRoundedArchive02,
                                title: 'Save packs',
                                subtitle:
                                    'Progress only — cartridge save & savestates',
                                selected: !isFull,
                                enabled: !_busy,
                                onTap: () => setState(
                                  () => _kind = GamePackKind.saves,
                                ),
                              ),
                              _KindOption(
                                icon: HugeIcons.strokeRoundedFloppyDisk,
                                title: 'Full packs',
                                subtitle:
                                    'ROM, art, library entry & progress',
                                selected: isFull,
                                enabled: !_busy,
                                onTap: () => setState(
                                  () => _kind = GamePackKind.full,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: HomeSpacing.sm,
                                ),
                                child: FilledButton(
                                  // Free: keep enabled so users can try + see
                                  // Pro toast (still need a selection when Pro).
                                  onPressed: _busy
                                      ? null
                                      : (!isPro
                                          ? _export
                                          : (selectedCount == 0
                                              ? null
                                              : _export)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: HomeColors.lemon,
                                    foregroundColor: HomeColors.onLemon,
                                    disabledBackgroundColor: HomeColors.lemon
                                        .withValues(alpha: 0.35),
                                    minimumSize: const Size.fromHeight(44),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: HomeSpacing.lg,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        HomeSizes.formRadius,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    exportLabel,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.w700,
                                      fontSize: HomeSizes.formBodySize,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: HomeSpacing.formSectionGap,
                              ),
                              const _SectionLabel(label: 'Import'),
                              const SizedBox(height: HomeSpacing.sm),
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: HomeSpacing.sm,
                                ),
                                child: Text(
                                  'Pick a multi Lemon pack '
                                  '(*.saves.multi.lemongba.zip or '
                                  '*.full.multi.lemongba.zip).',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: HomeSizes.formHintSize,
                                    color: HomeColors.labelDim,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              _NavActionTile(
                                icon: HugeIcons.strokeRoundedDownload01,
                                title: isPro
                                    ? 'Import multi pack…'
                                    : 'Import multi pack… (Pro)',
                                subtitle: isPro
                                    ? 'Restore saves or full library packs'
                                    : 'Pro unlocks restore from multi packs',
                                enabled: !_busy,
                                onTap: _importMulti,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: HomeSpacing.formColGap),
                        // ── Right: game multi-select ─────────────────────
                        // Scrollable so IME / short landscape does not
                        // overflow the fixed header + search chrome.
                        Expanded(
                          child: CustomScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            slivers: [
                              SliverToBoxAdapter(
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: _SectionLabel(label: 'Games'),
                                    ),
                                    Text(
                                      selectedCount == 0
                                          ? '${_allGames.length} total'
                                          : '$selectedCount selected',
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontWeight: FontWeight.w700,
                                        fontSize: HomeSizes.sectionLabelSize,
                                        letterSpacing: 0.4,
                                        color: HomeColors.labelDim,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: HomeSpacing.sm),
                              ),
                              SliverToBoxAdapter(
                                child: TextField(
                                  controller: _search,
                                  enabled: !_busy,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    color: HomeColors.labelOn,
                                  ),
                                  cursorColor: HomeColors.lemon,
                                  decoration: InputDecoration(
                                    hintText: 'Search games…',
                                    hintStyle: const TextStyle(
                                      fontFamily: 'Nunito',
                                      color: HomeColors.labelDim,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: HomeColors.labelDim,
                                      size: HomeSizes.sheetIconSize,
                                    ),
                                    isDense: true,
                                    filled: false,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: HomeSpacing.md,
                                      vertical: HomeSpacing.md - 2,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        HomeSizes.pillRadius,
                                      ),
                                      borderSide: const BorderSide(
                                        color: HomeColors.tileBorder,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        HomeSizes.pillRadius,
                                      ),
                                      borderSide: const BorderSide(
                                        color: HomeColors.lemon,
                                        width: 1.5,
                                      ),
                                    ),
                                    disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        HomeSizes.pillRadius,
                                      ),
                                      borderSide: BorderSide(
                                        color: HomeColors.tileBorder
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: Row(
                                  children: [
                                    const Spacer(),
                                    TextButton(
                                      onPressed: _busy || games.isEmpty
                                          ? null
                                          : _selectAllVisible,
                                      style: TextButton.styleFrom(
                                        foregroundColor: HomeColors.lemon,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: HomeSpacing.md,
                                          vertical: HomeSpacing.sm,
                                        ),
                                      ),
                                      child: const Text(
                                        'Select all',
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontWeight: FontWeight.w600,
                                          fontSize: HomeSizes.formHintSize,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _busy || selectedCount == 0
                                          ? null
                                          : _clearSelection,
                                      style: TextButton.styleFrom(
                                        foregroundColor: HomeColors.labelDim,
                                        disabledForegroundColor:
                                            HomeColors.labelDim.withValues(
                                          alpha: 0.4,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: HomeSpacing.md,
                                          vertical: HomeSpacing.sm,
                                        ),
                                      ),
                                      child: const Text(
                                        'Clear',
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontWeight: FontWeight.w600,
                                          fontSize: HomeSizes.formHintSize,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_allGames.isEmpty)
                                const SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: Text(
                                      'No games in library yet',
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        color: HomeColors.labelDim,
                                      ),
                                    ),
                                  ),
                                )
                              else if (games.isEmpty)
                                const SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: Text(
                                      'No matches',
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        color: HomeColors.labelDim,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) {
                                      final g = games[i];
                                      return ShellSheetCheckRow(
                                        label: g.title,
                                        selected: _selected.contains(g.id),
                                        onChanged: _busy
                                            ? (_) {}
                                            : (on) => _toggle(g.id, on),
                                        trailing: ShellMiniAvatar(
                                          monogram: g.monogram,
                                          path: _library.avatarAbsolutePath(g),
                                        ),
                                      );
                                    },
                                    childCount: games.length,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Free-tier callout — lets users browse Multi backup before unlocking Pro.
class _ProPreviewBanner extends StatelessWidget {
  const _ProPreviewBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HomeSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomeColors.lemon.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(HomeSizes.formRadius),
          border: Border.all(
            color: HomeColors.lemon.withValues(alpha: 0.4),
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(HomeSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCrown,
                size: HomeSizes.sheetHeaderIconSize,
                color: HomeColors.lemon,
              ),
              SizedBox(width: HomeSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pro feature',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: HomeSizes.formBodySize,
                        color: HomeColors.lemon,
                      ),
                    ),
                    SizedBox(height: HomeSpacing.xs),
                    Text(
                      'Browse multi export & import here. Unlock Pro to '
                      'export several games into one pack or restore a multi pack.',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: HomeSizes.formHintSize,
                        height: 1.35,
                        color: HomeColors.labelOn,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section label — matches Settings hub.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: HomeSizes.sectionLabelSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: HomeColors.labelDim,
      ),
    );
  }
}

/// Flat radio row — same density / type as Settings [_SettingsNavTile].
class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: HomeSpacing.sm,
        vertical: HomeSpacing.xs,
      ),
      leading: HugeIcon(
        icon: icon,
        size: HomeSizes.sheetHeaderIconSize,
        color: selected ? HomeColors.lemon : HomeColors.labelDim,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
          fontSize: HomeSizes.formBodySize,
          color: selected ? HomeColors.lemon : HomeColors.labelOn,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: HomeSizes.formHintSize,
          color: HomeColors.labelDim,
        ),
      ),
      trailing: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_off_rounded,
        size: 22,
        color: selected ? HomeColors.lemon : HomeColors.labelDim,
      ),
      onTap: enabled ? onTap : null,
    );
  }
}

/// Flat nav action — matches Settings list tiles (icon · title · chevron).
class _NavActionTile extends StatelessWidget {
  const _NavActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: HomeSpacing.sm,
        vertical: HomeSpacing.xs,
      ),
      leading: HugeIcon(
        icon: icon,
        size: HomeSizes.sheetHeaderIconSize,
        color: enabled ? HomeColors.lemon : HomeColors.labelDim,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
          fontSize: HomeSizes.formBodySize,
          color: enabled ? HomeColors.labelOn : HomeColors.labelDim,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: HomeSizes.formHintSize,
          color: HomeColors.labelDim,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: enabled ? HomeColors.labelDim : HomeColors.labelDim.withValues(alpha: 0.4),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}
