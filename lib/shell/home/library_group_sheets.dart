import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../models/game_group.dart';
import '../../models/library_game.dart';
import '../common/shell_art.dart';
import '../common/shell_sheet.dart';
import '../theme/home_tokens.dart';

/// Group options: rename / delete.
Future<void> showGroupActionsSheet({
  required BuildContext context,
  required GameGroup group,
  required VoidCallback onRename,
  required VoidCallback onDelete,
}) {
  return showShellModalSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return ShellSheetActionColumn(
        header: ShellSheetTitleBar(title: group.name),
        children: [
          ShellSheetAction(
            icon: HugeIcons.strokeRoundedEdit02,
            label: 'Rename',
            onTap: () {
              Navigator.pop(ctx);
              onRename();
            },
          ),
          ShellSheetAction(
            icon: HugeIcons.strokeRoundedDelete02,
            label: 'Delete group',
            color: HomeColors.missing,
            onTap: () {
              Navigator.pop(ctx);
              onDelete();
            },
          ),
          const SizedBox(height: HomeSpacing.sm),
        ],
      );
    },
  );
}

/// Bottom panel for create / rename group.
Future<String?> promptGroupName({
  required BuildContext context,
  required String title,
  String initial = '',
}) async {
  final result = await showShellModalSheet<String>(
    context: context,
    isScrollControlled: true,
    // Panel handles SafeArea + IME padding itself; Material's wrapper would
    // stack another bottom inset and clip/overflow on landscape keyboards.
    useSafeArea: false,
    builder: (ctx) {
      return _GroupNamePanel(
        title: title,
        initial: initial,
        confirmLabel: initial.isEmpty ? 'Create' : 'Save',
      );
    },
  );
  if (result == null) return null;
  final t = result.trim();
  return t.isEmpty ? null : t;
}

/// Multi-select games for a group (checkbox list + search).
Future<Set<String>?> pickGamesForGroup({
  required BuildContext context,
  required String title,
  required List<LibraryGame> games,
  required Set<String> initiallySelected,
  required String? Function(LibraryGame) avatarPathOf,
}) {
  return showShellModalSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return _PickGamesSheet(
        title: title,
        games: games,
        initiallySelected: initiallySelected,
        avatarPathOf: avatarPathOf,
      );
    },
  );
}

class _GroupNamePanel extends StatefulWidget {
  const _GroupNamePanel({
    required this.title,
    required this.initial,
    required this.confirmLabel,
  });

  final String title;
  final String initial;
  final String confirmLabel;

  @override
  State<_GroupNamePanel> createState() => _GroupNamePanelState();
}

class _GroupNamePanelState extends State<_GroupNamePanel> {
  static const double _fieldFont = HomeSizes.sheetBodySize;
  static const double _titleFont = HomeSizes.headerTitleSize;

  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _unfocus() {
    _focus.unfocus();
  }

  void _dismiss([String? result]) {
    // Best-effort IME hide on explicit actions. Barrier/drag pop also
    // unfocuses via [PopScope] below. Compact layout + parent
    // resizeToAvoidBottomInset:false are what stop the overflow stripe;
    // unfocus is polish (same-frame unfocus does not wait for IME inset).
    _unfocus();
    Navigator.pop(context, result);
  }

  void _submit() => _dismiss(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxBodyH = (MediaQuery.sizeOf(context).height - bottomInset)
        .clamp(0.0, double.infinity);

    // Compact, intrinsic-height sheet (not full-screen + Expanded).
    // App is landscape-only: with IME open, max height is often < 200px.
    // A forced full panel (or min height 200) overflows above the keyboard
    // and flashes yellow/black stripes while sheet + IME dismiss together.
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        // Cover barrier tap / drag-to-dismiss as well as button pops.
        if (didPop) _unfocus();
      },
      child: AnimatedPadding(
        duration: HomeMotion.imePad,
        curve: HomeMotion.imePadCurve,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: MediaQuery.removeViewInsets(
          removeBottom: true,
          context: context,
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxBodyH),
              child: SingleChildScrollView(
                // No bounce when content fits; scroll only if a11y scale /
                // tall IME still exceeds remaining landscape height.
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  HomeSpacing.lg,
                  HomeSpacing.sm,
                  HomeSpacing.lg,
                  HomeSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ShellSheetHandle(),
                    const SizedBox(height: HomeSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: _titleFont,
                              color: HomeColors.cream,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _dismiss(),
                          style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w600,
                              fontSize: HomeSizes.sheetActionSize,
                              color: HomeColors.labelDim,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _submit,
                          style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            widget.confirmLabel,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: HomeSizes.sheetActionSize,
                              color: HomeColors.lemon,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: HomeSpacing.lg),
                    Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: HomeSizes.confirmDialogMaxWidth,
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          maxLength: 40,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                            fontSize: _fieldFont,
                            color: HomeColors.labelOn,
                          ),
                          cursorColor: HomeColors.lemon,
                          decoration: InputDecoration(
                            hintText: 'e.g. Pokémon, Racing…',
                            hintStyle: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w600,
                              fontSize: _fieldFont,
                              color: HomeColors.labelDim,
                            ),
                            filled: true,
                            fillColor: HomeColors.tileFace,
                            counterText: '',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: HomeSpacing.lg + HomeSpacing.xs,
                              vertical: HomeSpacing.md,
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
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickGamesSheet extends StatefulWidget {
  const _PickGamesSheet({
    required this.title,
    required this.games,
    required this.initiallySelected,
    required this.avatarPathOf,
  });

  final String title;
  final List<LibraryGame> games;
  final Set<String> initiallySelected;
  final String? Function(LibraryGame) avatarPathOf;

  @override
  State<_PickGamesSheet> createState() => _PickGamesSheetState();
}

class _PickGamesSheetState extends State<_PickGamesSheet> {
  late final Set<String> _selected;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initiallySelected);
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<LibraryGame> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.games;
    return widget.games
        .where((g) => g.title.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height -
        MediaQuery.viewPaddingOf(context).top;
    final filtered = _filtered;

    return SafeArea(
      left: false,
      right: false,
      child: SizedBox(
        height: h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShellSheetTitleBar(
              title: widget.title,
              trailing: TextButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: HomeSizes.sheetActionSize,
                    color: HomeColors.lemon,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HomeSpacing.sheetTitlePadH,
                0,
                HomeSpacing.sheetTitlePadH,
                HomeSpacing.sm,
              ),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  color: HomeColors.labelOn,
                ),
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
                  filled: true,
                  fillColor: HomeColors.tileFace,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: HomeSpacing.md,
                    vertical: HomeSpacing.md - 2,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HomeSizes.pillRadius),
                    borderSide: const BorderSide(color: HomeColors.tileBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HomeSizes.pillRadius),
                    borderSide: const BorderSide(
                      color: HomeColors.lemon,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matches',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          color: HomeColors.labelDim,
                        ),
                      ),
                    )
                  : ListView.builder(
                      // Clamp: no iOS bounce when the list is shorter than
                      // the expanded pane (feels like a bogus scroll).
                      physics: const ClampingScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final g = filtered[i];
                        return ShellSheetCheckRow(
                          label: g.title,
                          selected: _selected.contains(g.id),
                          onChanged: (on) {
                            setState(() {
                              if (on) {
                                _selected.add(g.id);
                              } else {
                                _selected.remove(g.id);
                              }
                            });
                          },
                          trailing: ShellMiniAvatar(
                            monogram: g.monogram,
                            path: widget.avatarPathOf(g),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
