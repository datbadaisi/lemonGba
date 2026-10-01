import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/entitlements/free_limits.dart';
import '../../infrastructure/entitlements/pro_access.dart';
import '../../infrastructure/entitlements/pro_billing.dart';
import '../../infrastructure/play/play_layout_store.dart';
import '../common/app_toast.dart';
import '../common/console_chrome.dart';
import '../common/legal_urls.dart';
import '../common/shell_page_header.dart';
import '../theme/home_tokens.dart';
import 'licenses_screen.dart';
import '../play/layout/play_layout_editor_screen.dart';

/// Minimal settings hub opened from the home circular gear button.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.coreVersion,
    required this.pro,
    required this.billing,
    required this.playLayout,
  });

  final String coreVersion;
  final ProAccess pro;
  final ProBilling billing;
  final PlayLayoutStore playLayout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Play billing sheet is a separate activity — when it closes (buy or
  /// cancel), we resume and must clear a stuck spinner if the stream was silent.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.billing.onHostResumed();
    }
  }

  Future<void> _openExternal(BuildContext context, Uri url) async {
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        AppToast.error(context, 'Could not open link.');
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context, 'Could not open link.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pro = widget.pro;
    final billing = widget.billing;
    final coreVersion = widget.coreVersion;

    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: ConsoleChrome(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ShellPageHeader(title: 'Settings'),
            Expanded(
              child: Padding(
                padding: HomeSpacing.formContentPad,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Left: payment / Pro ───────────────────────────────
                    Expanded(
                      child: ListView(
                        children: [
                          const _SectionLabel(label: 'Payment'),
                          const SizedBox(height: HomeSpacing.sm),
                          ListenableBuilder(
                            listenable: Listenable.merge([pro, billing]),
                            builder: (context, _) {
                              return _ProCard(pro: pro, billing: billing);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: HomeSpacing.formColGap),
                    // ── Right: app settings ───────────────────────────────
                    Expanded(
                      child: ListView(
                        children: [
                          const _SectionLabel(label: 'Settings'),
                          const SizedBox(height: HomeSpacing.sm),
                          _SettingsNavTile(
                            icon: HugeIcons.strokeRoundedGameController03,
                            title: 'Control layout',
                            subtitle: 'Move & resize on-screen controls',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PlayLayoutEditorScreen(
                                    store: widget.playLayout,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: HomeSpacing.md),
                          _SettingsNavTile(
                            icon: HugeIcons.strokeRoundedBalanceScale,
                            title: 'Open source licenses',
                            subtitle: 'GPL-3.0, mGBA and font notices',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      LicensesScreen(coreVersion: coreVersion),
                                ),
                              );
                            },
                          ),
                          if (LegalUrls.privacyPolicy case final privacy?) ...[
                            const SizedBox(height: HomeSpacing.md),
                            _SettingsNavTile(
                              icon: HugeIcons.strokeRoundedSecurityCheck,
                              title: 'Privacy Policy',
                              subtitle: 'How we handle your data',
                              onTap: () => _openExternal(context, privacy),
                            ),
                          ],
                          if (LegalUrls.termsOfService case final terms?) ...[
                            const SizedBox(height: HomeSpacing.md),
                            _SettingsNavTile(
                              icon: HugeIcons.strokeRoundedLegalDocument01,
                              title: 'Terms of Service',
                              subtitle: 'Rules for using lemonGba',
                              onTap: () => _openExternal(context, terms),
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
    );
  }
}

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

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: HomeSpacing.sm,
        vertical: HomeSpacing.xs,
      ),
      leading: HugeIcon(
        icon: icon,
        size: HomeSizes.sheetHeaderIconSize,
        color: HomeColors.lemon,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
          fontSize: HomeSizes.formBodySize,
          color: HomeColors.labelOn,
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
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: HomeColors.labelDim,
      ),
      onTap: onTap,
    );
  }
}

/// Crown leading icon with a soft rounded box background.
class _CrownIconBox extends StatelessWidget {
  const _CrownIconBox({required this.isPro});

  final bool isPro;

  static const double _size = 40;
  static const double _radius = 10;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isPro
            ? HomeColors.lemon.withValues(alpha: 0.16)
            : HomeColors.tileFace,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: isPro
              ? HomeColors.lemon.withValues(alpha: 0.35)
              : HomeColors.tileBorder,
        ),
      ),
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedCrown,
        size: HomeSizes.sheetHeaderIconSize,
        color: isPro ? HomeColors.lemon : HomeColors.labelDim,
      ),
    );
  }
}

/// Lifetime Pro — Play purchase / restore (debug toggle only in debug builds).
///
/// Flat list language (matches [_SettingsNavTile]), not a promo card.
class _ProCard extends StatelessWidget {
  const _ProCard({required this.pro, required this.billing});

  final ProAccess pro;
  final ProBilling billing;

  Future<void> _buy(BuildContext context) async {
    final outcome = await billing.buyAndAwait();
    if (!context.mounted) return;
    switch (outcome) {
      case ProBillingOutcome.unlocked:
      case ProBillingOutcome.alreadyPro:
        AppToast.success(context, 'Pro unlocked — thank you!');
      case ProBillingOutcome.error:
        AppToast.error(context, billing.lastError ?? 'Purchase failed.');
      case ProBillingOutcome.canceled:
      case ProBillingOutcome.notFound:
        // User closed the sheet — silent.
        break;
    }
  }

  Future<void> _restore(BuildContext context) async {
    final outcome = await billing.restoreAndAwait();
    if (!context.mounted) return;
    switch (outcome) {
      case ProBillingOutcome.unlocked:
        AppToast.success(context, 'Purchases restored — Pro unlocked.');
      case ProBillingOutcome.alreadyPro:
        AppToast.success(context, 'Pro is already active on this device.');
      case ProBillingOutcome.error:
        AppToast.error(
          context,
          billing.lastError ?? 'Could not restore purchases.',
        );
      case ProBillingOutcome.notFound:
      case ProBillingOutcome.canceled:
        AppToast.error(
          context,
          'No lifetime purchase found for this Google account.',
        );
    }
  }

  Future<void> _onBuyPressed(BuildContext context) async {
    if (billing.product == null) {
      await billing.loadProduct();
      if (!context.mounted) return;
    }
    if (billing.product == null) {
      AppToast.error(
        context,
        billing.lastError ??
            'Product not available. Install from Play testing track.',
      );
      return;
    }
    await _buy(context);
  }

  @override
  Widget build(BuildContext context) {
    final isPro = pro.isPro;
    final busy = billing.buying || billing.loading;
    final price = billing.priceLabel;
    final buyLabel = price == null
        ? 'Unlock Pro — lifetime'
        : 'Lifetime Pro — $price';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Plan status — same padding / density as settings tiles.
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: HomeSpacing.sm,
            vertical: HomeSpacing.xs,
          ),
          leading: _CrownIconBox(isPro: isPro),
          title: Text(
            isPro ? 'Pro unlocked' : 'Free plan',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
              fontSize: HomeSizes.formBodySize,
              color: isPro ? HomeColors.lemon : HomeColors.labelOn,
            ),
          ),
          subtitle: Text(
            isPro
                ? 'Unlimited tiles, covers & groups · multi backup'
                : 'Lifetime unlock · unlimited tiles, covers & groups · multi backup',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: HomeSizes.formHintSize,
              color: HomeColors.labelDim,
            ),
          ),
          trailing: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: HomeColors.lemon,
                  ),
                )
              : null,
        ),
        if (!isPro) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HomeSpacing.sm,
              HomeSpacing.xs,
              HomeSpacing.sm,
              HomeSpacing.md,
            ),
            child: Text(
              'Free limits: ${FreeLimits.maxAvatars} tile images · '
              '${FreeLimits.maxCovers} cover · '
              '${FreeLimits.maxGroups} group · '
              'multi backup is Pro',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: HomeSizes.formHintSize,
                height: 1.35,
                color: HomeColors.labelDim,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HomeSpacing.sm),
            child: FilledButton(
              onPressed: busy ? null : () => _onBuyPressed(context),
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.lemon,
                foregroundColor: HomeColors.onLemon,
                disabledBackgroundColor: HomeColors.lemon.withValues(
                  alpha: 0.35,
                ),
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(horizontal: HomeSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HomeSizes.formRadius),
                ),
              ),
              child: Text(
                buyLabel,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: HomeSizes.formBodySize,
                ),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: busy ? null : () => _restore(context),
              style: TextButton.styleFrom(
                foregroundColor: HomeColors.labelDim,
                padding: const EdgeInsets.symmetric(
                  horizontal: HomeSpacing.lg,
                  vertical: HomeSpacing.md,
                ),
              ),
              child: const Text(
                'Restore purchases',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: HomeSizes.formBodySize,
                ),
              ),
            ),
          ),
          if (billing.lastError != null && !busy)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HomeSpacing.sm,
                0,
                HomeSpacing.sm,
                HomeSpacing.xs,
              ),
              child: Text(
                billing.lastError!,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: HomeSizes.formHintSize,
                  height: 1.3,
                  color: HomeColors.missing.withValues(alpha: 0.9),
                ),
              ),
            ),
        ] else
          Center(
            child: TextButton(
              onPressed: busy ? null : () => _restore(context),
              style: TextButton.styleFrom(
                foregroundColor: HomeColors.labelDim,
                padding: const EdgeInsets.symmetric(
                  horizontal: HomeSpacing.lg,
                  vertical: HomeSpacing.md,
                ),
              ),
              child: const Text(
                'Restore purchases',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: HomeSizes.formBodySize,
                ),
              ),
            ),
          ),
        if (kDebugMode) ...[
          const SizedBox(height: HomeSpacing.sm),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: HomeSpacing.sm,
            ),
            title: const Text(
              'Debug: force Pro',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: HomeSizes.formHintSize,
                color: HomeColors.labelDim,
              ),
            ),
            trailing: Switch.adaptive(
              value: isPro,
              activeThumbColor: HomeColors.lemon,
              onChanged: (v) => pro.setPro(v),
            ),
          ),
        ],
      ],
    );
  }
}
