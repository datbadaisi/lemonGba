import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/console_chrome.dart';
import '../common/legal_urls.dart';
import '../common/shell_page_header.dart';
import '../theme/home_tokens.dart';

/// License notices and source links for the app and its native core.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key, required this.coreVersion});

  final String coreVersion;

  static final _mgbaSource = Uri.parse('https://github.com/mgba-emu/mgba');
  static final _mpl = Uri.parse('https://www.mozilla.org/MPL/2.0/');
  static final _gpl = Uri.parse('https://www.gnu.org/licenses/gpl-3.0.html');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: ConsoleChrome(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ShellPageHeader(title: 'Open source licenses'),
            Expanded(
              child: ListView(
                padding: HomeSpacing.formContentPad,
                children: [
                  const Text(
                    'lemonGba',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: HomeSizes.headerTitleSize,
                      color: HomeColors.cream,
                    ),
                  ),
                  const SizedBox(height: HomeSpacing.sm),
                  const Text(
                    'Project-authored code is licensed under GPL-3.0-only. '
                    'The project source and full license text are available '
                    'in the public repository. Bundled components retain '
                    'their own licenses.',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: HomeSizes.formBodySize,
                      color: HomeColors.labelOn,
                      height: 1.4,
                    ),
                  ),
                  if (LegalUrls.projectSource case final projectSource?)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Project source and GPL-3.0 license'),
                      subtitle: Text(projectSource.toString()),
                      onTap: () => launchUrl(
                        projectSource,
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('GNU GPL version 3'),
                    subtitle: Text(_gpl.toString()),
                    onTap: () =>
                        launchUrl(_gpl, mode: LaunchMode.externalApplication),
                  ),
                  const SizedBox(height: HomeSpacing.xl),
                  const Text(
                    'mGBA',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: HomeSizes.headerTitleSize,
                      color: HomeColors.cream,
                    ),
                  ),
                  const SizedBox(height: HomeSpacing.sm),
                  Text(
                    'Bundled version: $coreVersion',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: HomeSizes.formBodySize,
                      color: HomeColors.labelOn,
                    ),
                  ),
                  const SizedBox(height: HomeSpacing.sm),
                  const Text(
                    'This app embeds mGBA, which is licensed under the Mozilla '
                    'Public License 2.0 (MPL-2.0).\n\n'
                    'You can obtain the corresponding source code of mGBA from '
                    'the upstream repository (and from this project\'s '
                    'native/mgba tree / any published fork that matches the '
                    'build).',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: HomeSizes.formBodySize,
                      color: HomeColors.labelOn,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: HomeSpacing.lg),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCode,
                      size: HomeSizes.sheetHeaderIconSize,
                      color: HomeColors.lemon,
                    ),
                    title: const Text(
                      'mGBA source (upstream)',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        fontSize: HomeSizes.formBodySize,
                        color: HomeColors.labelOn,
                      ),
                    ),
                    subtitle: Text(
                      _mgbaSource.toString(),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: HomeSizes.formHintSize,
                        color: HomeColors.labelDim,
                      ),
                    ),
                    onTap: () => launchUrl(
                      _mgbaSource,
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const HugeIcon(
                      icon: HugeIcons.strokeRoundedLegalHammer,
                      size: HomeSizes.sheetHeaderIconSize,
                      color: HomeColors.lemon,
                    ),
                    title: const Text(
                      'Mozilla Public License 2.0',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        fontSize: HomeSizes.formBodySize,
                        color: HomeColors.labelOn,
                      ),
                    ),
                    subtitle: Text(
                      _mpl.toString(),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: HomeSizes.formHintSize,
                        color: HomeColors.labelDim,
                      ),
                    ),
                    onTap: () =>
                        launchUrl(_mpl, mode: LaunchMode.externalApplication),
                  ),
                  const SizedBox(height: HomeSpacing.xl),
                  const Text(
                    'Nunito font: SIL Open Font License 1.1. The font license '
                    'is included at assets/fonts/OFL.txt in the project source.',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: HomeSizes.formHintSize,
                      color: HomeColors.labelDim,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: HomeSpacing.sm),
                  const Text(
                    'If you modify any MPL-covered files under native/mgba or '
                    'the bridge copies of mGBA code, you must make those '
                    'modifications available under MPL-2.0 to recipients of '
                    'the app binary.',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: HomeSizes.formHintSize,
                      color: HomeColors.labelDim,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
