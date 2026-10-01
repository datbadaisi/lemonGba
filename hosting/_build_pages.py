# -*- coding: utf-8 -*-
from html import escape
import json
from pathlib import Path
import re

BASE = Path(__file__).resolve().parent / "public"
CONFIG = Path(__file__).resolve().parent / "site_config.json"

# Bump when styles.css changes so browsers skip stale cache.
CSS_VERSION = "5"


def wrap(title: str, desc: str, active: str, content_html: str) -> str:
    privacy_active = ' class="active"' if active == "privacy" else ""
    terms_active = ' class="active"' if active == "terms" else ""
    deletion_active = ' class="active"' if active == "deletion" else ""
    return f"""<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1, viewport-fit=cover"
    />
    <meta name="theme-color" content="#000000" />
    <meta name="color-scheme" content="dark" />
    <meta name="description" content="{desc}" />
    <title>{title}</title>
    <link rel="icon" href="/assets/app_icon.png" type="image/png" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700;800&display=swap"
      rel="stylesheet"
    />
    <link rel="stylesheet" href="/styles.css?v={CSS_VERSION}" />
  </head>
  <body>
    <div class="shell">
      <header class="topbar">
        <div class="topbar-inner">
          <a class="brand" href="/">
            <img src="/assets/app_icon.png" alt="" width="30" height="30" />
            lemonGba
          </a>
          <nav class="nav" aria-label="Legal">
            <a href="/privacy/"{privacy_active}>Privacy</a>
            <a href="/terms/"{terms_active}>Terms</a>
            <a href="/data-deletion/"{deletion_active}>Delete data</a>
          </nav>
        </div>
      </header>

      <main class="main">
{content_html}
      </main>

      <footer class="footer">
        © <span id="y"></span> lemonGba ·
        <a href="/privacy/">Privacy</a> ·
        <a href="/terms/">Terms</a> ·
        <a href="/data-deletion/">Delete data</a>
      </footer>
    </div>
    <script>
      document.getElementById("y").textContent = new Date().getFullYear();
    </script>
  </body>
</html>
"""


PRIVACY = r"""        <p class="eyebrow">Legal</p>
        <h1>Privacy Policy</h1>
        <p class="meta">
          Effective date: August 9, 2026 · Last updated: September 25, 2026<br />
          App: <strong>lemonGba</strong> (package
          <code>com.thezello.lemongba</code>)
        </p>

        <div class="prose">
          <p>
            This Privacy Policy explains how <strong>lemonGba</strong> (“we”,
            “us”, “the App”) handles information when you use our Android
            application. We designed lemonGba to keep game data on your device
            whenever possible.
          </p>

          <div class="note">
            <strong>Short version:</strong> lemonGba does not require an
            account. ROMs, saves, cover art, and settings stay on your device.
            Lifetime Pro unlocks the full feature set through Google Play
            Billing. We do not sell your personal information.
          </div>

          <h2>1. Who we are</h2>
          <p>
            lemonGba is a Game Boy Advance emulator shell powered by the open
            source mGBA core. The developer of this App is the publisher of the
            lemonGba listing on Google Play (developer identity “thezello” /
            package <strong>com.thezello.lemongba</strong>).
          </p>

          <h2>2. Information we process</h2>

          <h3>2.1 Data stored only on your device</h3>
          <p>The App stores the following locally on your device (app storage):</p>
          <ul>
            <li>ROM files you import and related library metadata (names, groups, notes)</li>
            <li>Cartridge save data (<code>.sav</code>) and save states</li>
            <li>Custom tile images, cover art, and on-screen control layout preferences</li>
            <li>Pro entitlement flags synced from Google Play purchase status</li>
            <li>App preferences and display settings</li>
          </ul>
          <p>
            We do <strong>not</strong> operate a lemonGba cloud account that
            receives your ROMs or save files. Backup packs you export remain
            under your control (e.g. files you share or store yourself).
          </p>

          <h3>2.2 Information we do not collect directly</h3>
          <p>lemonGba does not ask you to create an account and does not request:</p>
          <ul>
            <li>Your name, email, or postal address inside the App</li>
            <li>Access to your contacts, camera, or microphone for core play</li>
            <li>Location for gameplay features</li>
          </ul>

          <h3>2.3 In-app purchases</h3>
          <p>
            Lifetime Pro is sold through <strong>Google Play Billing</strong>.
            Payment details are processed by Google; lemonGba does not receive or
            store your full payment card information. Google may share with us
            purchase tokens / entitlement signals needed to unlock Pro on your
            device. See
            <a href="https://payments.google.com/payments/apis-secure/u/0/get_legal_document?ldo=0&amp;ldt=privacynotice" target="_blank" rel="noopener noreferrer">Google Payments privacy notice</a>.
          </p>

          <h3>2.4 Diagnostics and crash data</h3>
          <p>
            Depending on your device and Play settings, Google Play or the
            Android system may collect crash reports and basic app performance
            data. We may review aggregated crash or ANR reports provided by
            Google Play Console to fix bugs. We do not intentionally include ROM
            file contents in those reports.
          </p>

          <h2>3. How we use information</h2>
          <p>Information processed in connection with the App is used to:</p>
          <ul>
            <li>Run emulation, library, saves, and UI features on your device</li>
            <li>Validate and restore Pro purchases</li>
            <li>Improve stability and fix defects</li>
            <li>Comply with law and enforce our Terms of Service</li>
          </ul>

          <h2>4. Legal bases (EEA/UK where applicable)</h2>
          <p>Where GDPR or UK GDPR applies, processing is based on:</p>
          <ul>
            <li>
              <strong>Contract / service delivery</strong> — providing the App
              features you request (local storage of library and saves)
            </li>
            <li>
              <strong>Legitimate interests</strong> — app security, basic
              analytics/crash triage, fraud prevention around purchases
            </li>
          </ul>

          <h2>5. Sharing</h2>
          <p>We do not sell your personal information. Categories of recipients:</p>
          <ul>
            <li>
              <strong>Google (Play Billing, Play services)</strong> —
              payments, distribution
            </li>
            <li>
              <strong>Service providers</strong> we may use solely to host this
              legal website (Firebase Hosting) or operate infrastructure —
              without access to your ROMs
            </li>
            <li>
              <strong>Authorities</strong> when required by law or to protect
              rights and safety
            </li>
          </ul>

          <h2>6. Data retention</h2>
          <ul>
            <li>
              Local library, ROMs, saves, and settings remain until you delete
              them in the App or uninstall / clear app data.
            </li>
            <li>
              Purchase records are retained by Google according to their
              policies; Pro status may re-sync when you restore purchases.
            </li>
          </ul>

          <h2>7. Security</h2>
          <p>
            We rely on Android app sandboxing and standard platform protections.
            No method of electronic storage is 100% secure. You are responsible
            for physical access to your device and for any backup files you
            export or share.
          </p>

          <h2>8. Children’s privacy</h2>
          <p>
            lemonGba is not directed at children under 13 (or the minimum age in
            your country). We do not knowingly collect personal information from
            children. If you have privacy concerns, contact us using the method
            below.
          </p>

          <h2>9. International transfers</h2>
          <p>
            Google and other processors may process data on servers outside your
            country. Where required, such transfers are covered by appropriate
            safeguards under those providers’ terms.
          </p>

          <h2>10. Your rights and choices</h2>
          <p>
            Depending on your location, you may have rights to access, correct,
            delete, or restrict processing of personal data, and to object or
            lodge a complaint with a supervisory authority. Because most App data
            lives only on your device, you can usually exercise control by:
          </p>
          <ul>
            <li>Deleting games, images, or app data from Settings / system settings</li>
            <li>Uninstalling the App</li>
            <li>Managing Play purchases in your Google account</li>
          </ul>
          <p>
            For requests about data we control outside the device (e.g. Play
            Console contact), use the contact method below.
          </p>

          <h2>11. Third-party open source</h2>
          <p>
            lemonGba embeds <strong>mGBA</strong> (Mozilla Public License 2.0)
            and other open source components. Those projects may have their own
            notices; they do not change how lemonGba handles your personal data
            as described here. See Open source licenses inside the App.
          </p>

          <h2>12. Changes to this policy</h2>
          <p>
            We may update this Privacy Policy from time to time. The “Last
            updated” date at the top will change when we do. Continued use of
            the App after an update means you acknowledge the revised policy.
            Material changes may also be noted on the Play Store listing when
            appropriate.
          </p>

          <div class="contact">
            <h2>13. Contact</h2>
            <p>
              Questions about this Privacy Policy or privacy requests for
              lemonGba:
            </p>
            <p>
              Email:
              <a href="mailto:{{CONTACT_EMAIL}}">{{CONTACT_EMAIL}}</a><br />
              Subject line suggestion: <strong>lemonGba Privacy</strong>
            </p>
            <p class="meta" style="margin-bottom: 0">
              Related:
              <a href="/terms/">Terms of Service</a> ·
              <a href="/data-deletion/">Data deletion</a>
            </p>
          </div>
        </div>"""

DELETION = r"""        <p class="eyebrow">Legal</p>
        <h1>Request deletion of your data</h1>
        <p class="meta">
          Last updated: September 25, 2026<br />
          App: <strong>lemonGba</strong> (package
          <code>com.thezello.lemongba</code>)<br />
          Developer / Play listing identity: <strong>thezello</strong>
        </p>

        <div class="prose">
          <p>
            This page explains how users of the Android app
            <strong>lemonGba</strong> (published by <strong>thezello</strong>
            on Google Play) can request deletion of their data. lemonGba does
            not require an account and does not operate a user-profile backend.
          </p>

          <div class="note">
            <strong>Quick path:</strong> Uninstall lemonGba to remove on-device
            app data immediately. Email us if you need a deletion request
            recorded or help with third-party Google Play Billing data.
          </div>

          <h2>1. How to request deletion</h2>
          <p>Follow these steps:</p>
          <ol>
            <li>
              <strong>On-device data (you can do this yourself):</strong>
              <ul>
                <li>
                  Open Android <strong>Settings → Apps → lemonGba → Storage</strong>
                  and choose <strong>Clear storage</strong> / <strong>Clear data</strong>,
                  or
                </li>
                <li>
                  <strong>Uninstall</strong> lemonGba. This permanently removes
                  ROMs you imported into app storage, cartridge saves, save
                  states, cover/tile images, layout preferences, and the local
                  Pro cache on that device.
                </li>
              </ul>
            </li>
            <li>
              <strong>Email request (recommended for a written record):</strong>
              send a message to
              <a href="mailto:{{CONTACT_EMAIL}}?subject=lemonGba%20Data%20Deletion"
                >{{CONTACT_EMAIL}}</a>
              with subject line
              <strong>lemonGba Data Deletion</strong>.
            </li>
            <li>
              In the email, include:
              <ul>
                <li>That the request is for the app <strong>lemonGba</strong></li>
                <li>The Google Play order ID or purchase email <em>only if</em>
                  your request relates to a Pro purchase support issue (optional)</li>
                <li>Any other detail that helps us identify residual contact
                  (e.g. a prior support email you sent)</li>
              </ul>
            </li>
            <li>
              We will confirm receipt and complete handling of data
              <strong>we control</strong> within <strong>30 days</strong>
              (often sooner). You do not need a password or in-app account.
            </li>
          </ol>

          <h2>2. What is deleted</h2>
          <table>
            <thead>
              <tr>
                <th>Data</th>
                <th>Where it lives</th>
                <th>How it is deleted / retained</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Imported ROMs, library metadata, covers, tiles</td>
                <td>Your device (app storage)</td>
                <td>
                  <strong>Deleted</strong> when you clear app data or uninstall.
                  We do not host copies on our servers.
                </td>
              </tr>
              <tr>
                <td>Cartridge <code>.sav</code>, save states, control layout, settings</td>
                <td>Your device</td>
                <td>
                  <strong>Deleted</strong> on clear data / uninstall. Backups you
                  exported yourself (e.g. share/export packs) remain under your
                  control until you delete those files.
                </td>
              </tr>
              <tr>
                <td>Local Pro entitlement flag</td>
                <td>Your device</td>
                <td>
                  <strong>Deleted</strong> on clear data / uninstall. Your
                  Google Play purchase record remains with Google; Restore can
                  re-apply Pro after reinstall.
                </td>
              </tr>
              <tr>
                <td>Support / deletion request emails you send us</td>
                <td>Our email inbox</td>
                <td>
                  Used only to process your request. We
                  <strong>delete or anonymize</strong> these messages within
                  <strong>90 days</strong> after the request is closed, unless
                  law requires longer retention (e.g. dispute records).
                </td>
              </tr>
              <tr>
                <td>In-app purchase / Play Billing records</td>
                <td>Google Play</td>
                <td>
                  <strong>Retained by Google</strong> as required for payments,
                  taxes, and fraud prevention. We cannot erase Google’s payment
                  ledger. Manage purchases in your Google Play account.
                </td>
              </tr>
            </tbody>
          </table>

          <h2>3. What we do not collect</h2>
          <p>
            lemonGba does not create user accounts and does not store your ROMs,
            saves, or library on developer-operated cloud servers. There is no
            lemonGba cloud profile to wipe beyond the contact records described
            above.
          </p>

          <h2>4. Retention summary</h2>
          <ul>
            <li>
              <strong>On-device app data:</strong> retained until you clear data
              or uninstall (under your control).
            </li>
            <li>
              <strong>Email you send for deletion/support:</strong> up to
              90 days after closure, then deleted or anonymized unless legal
              retention applies.
            </li>
            <li>
              <strong>Google Play Billing:</strong> retained by Google
              under Google’s own retention periods; not controlled by the
              lemonGba developer except through product configuration.
            </li>
          </ul>

          <h2>5. Related policies</h2>
          <p>
            Full details:
            <a href="/privacy/">Privacy Policy</a> ·
            <a href="/terms/">Terms of Service</a>
          </p>

          <div class="contact">
            <h2>6. Contact</h2>
            <p>
              Data deletion requests for <strong>lemonGba</strong>
              (developer <strong>thezello</strong>):
            </p>
            <p>
              Email:
              <a href="mailto:{{CONTACT_EMAIL}}?subject=lemonGba%20Data%20Deletion"
                >{{CONTACT_EMAIL}}</a><br />
              Subject: <strong>lemonGba Data Deletion</strong>
            </p>
          </div>
        </div>"""

TERMS = r"""        <p class="eyebrow">Legal</p>
        <h1>Terms of Service</h1>
        <p class="meta">
          Effective date: August 9, 2026 · Last updated: September 25, 2026<br />
          App: <strong>lemonGba</strong> (package
          <code>com.thezello.lemongba</code>)
        </p>

        <div class="prose">
          <p>
            These Terms of Service (“Terms”) describe our optional Google Play
            purchase and related services for <strong>lemonGba</strong> (the
            “App”), a Game Boy Advance emulator shell for Android. Rights to
            use, copy, modify, and share the software come from its open source
            licenses, regardless of these Terms.
          </p>

          <div class="note">
            <strong>Important:</strong> You must only use ROMs and game content
            that you have the legal right to use. lemonGba does not provide,
            sell, or host copyrighted game ROMs.
          </div>

          <h2>1. The service</h2>
          <p>
            lemonGba lets you import Game Boy Advance ROM files you provide, play
            them using an embedded open source emulator core (mGBA), manage a
            local game library, save progress, customize on-screen controls, and
            optionally purchase a lifetime Pro upgrade. Features may change over
            time as we update the App.
          </p>

          <h2>2. Eligibility</h2>
          <p>
            Google Play purchases and services are subject to Google's account
            and age rules. The App is not directed to children under 13. Your
            rights under the open source licenses are unaffected.
          </p>

          <h2>3. Open source license</h2>
          <p>
            Project-authored App code is licensed under GPL-3.0-only. Bundled
            mGBA and other third-party materials retain their own licenses.
            You may use, copy, modify, and redistribute covered materials under
            those licenses. These Terms add no restrictions to those rights.
          </p>
          <p>
            You are responsible for using ROMs and other content lawfully.
            A copy or fork of the App does not transfer a Google Play purchase
            or access to our optional services.
          </p>

          <h2>4. ROMs, saves, and user content</h2>
          <p>
            You are solely responsible for the files you import, including ROMs,
            images, and backup packs. You represent that you have all rights
            needed to use that content with the App.
          </p>
          <ul>
            <li>
              lemonGba does <strong>not</strong> supply copyrighted commercial
              game ROMs.
            </li>
            <li>
              Library data, saves, and art are stored on your device unless you
              export or share them yourself.
            </li>
            <li>
              We do not claim ownership of your ROMs or personal save files.
            </li>
          </ul>
          <p>
            If you export multi-game backup packs (Pro) or share files, you are
            responsible for how those files are stored and who receives them.
          </p>

          <h2>5. Free plan and Pro</h2>
          <h3>5.1 Free plan</h3>
          <p>
            The free plan includes product limits (for
            example: limited custom tile images, covers, groups, and no multi
            backup). Limits are described in the App and may be updated.
          </p>
          <h3>5.2 Lifetime Pro</h3>
          <p>
            “Pro” is a one-time in-app purchase offered through Google Play
            Billing (where available). It unlocks the full feature set,
            including removal of free-tier limits. Exact benefits are shown in
            the App at purchase time.
          </p>
          <ul>
            <li>Prices are set in Google Play and may vary by region and tax.</li>
            <li>
              Purchases are processed by Google; refunds and billing disputes are
              handled under Google Play’s policies unless mandatory consumer law
              says otherwise.
            </li>
            <li>
              You can use Restore purchases to re-link an existing lifetime
              purchase to a device signed into the same Google account.
            </li>
            <li>
              A Pro purchase is tied to the purchasing Google account; it does
              not change your rights under the App's open source licenses.
            </li>
          </ul>

          <h2>6. Open source components</h2>
          <p>
            Project-authored App code is licensed under GPL-3.0-only. The App
            embeds <strong>mGBA</strong> and other third-party materials under
            their respective licenses (including MPL-2.0 for mGBA and OFL-1.1
            for Nunito). Those licenses continue to apply to the covered
            materials. Nothing in these Terms limits your rights under those
            licenses. See “Open source licenses” in the App for notices and
            source information.
          </p>

          <h2>7. Intellectual property</h2>
          <p>
            lemonGba branding and original artwork are owned by us or our
            licensors. The source code license grants rights to the covered
            code. Nintendo, Game Boy Advance, and game titles are
            trademarks of their respective owners. lemonGba is an independent
            project and is not affiliated with, endorsed by, or sponsored by
            Nintendo.
          </p>

          <h2>8. Third-party services</h2>
          <p>
            The App may integrate Google Play Billing and system services.
            Your use of those services is also
            subject to Google’s terms and policies. We are not responsible for
            third-party outages, policy changes, or store decisions.
          </p>

          <h2>9. Disclaimer of warranties</h2>
          <p>
            THE APP IS PROVIDED “AS IS” AND “AS AVAILABLE” WITHOUT WARRANTIES OF
            ANY KIND, WHETHER EXPRESS, IMPLIED, OR STATUTORY, INCLUDING IMPLIED
            WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
            NON-INFRINGEMENT, TO THE MAXIMUM EXTENT PERMITTED BY LAW.
          </p>
          <p>
            We do not warrant that emulation will be accurate for every title,
            that the App will be uninterrupted or error-free, or that saves will
            never be lost. Always keep your own backups of important save data.
          </p>

          <h2>10. Limitation of liability</h2>
          <p>
            TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE AND OUR SUPPLIERS WILL
            NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL,
            EXEMPLARY, OR PUNITIVE DAMAGES, OR ANY LOSS OF DATA, PROFITS, OR
            GOODWILL, ARISING FROM YOUR USE OF (OR INABILITY TO USE) THE APP.
          </p>
          <p>
            OUR TOTAL LIABILITY FOR ANY CLAIM ARISING OUT OF THESE TERMS OR THE
            APP WILL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU PAID US FOR
            PRO IN THE TWELVE (12) MONTHS BEFORE THE CLAIM OR (B) TEN US DOLLARS
            (US $10), EXCEPT WHERE LIABILITY CANNOT BE LIMITED UNDER APPLICABLE
            LAW.
          </p>
          <p>
            Some jurisdictions do not allow certain limitations; in those cases,
            the above limits apply only to the fullest extent permitted.
          </p>

          <h2>11. Availability of services</h2>
          <p>
            We may stop offering our distribution or optional services, or
            change features, subject to law and platform rules. This does not
            revoke rights already granted under open source licenses.
          </p>

          <h2>12. Changes to the Terms</h2>
          <p>
            We may update these Terms. The “Last updated” date will change when
            we do. Changes to these Terms do not change rights already granted
            under open source licenses.
          </p>

          <h2>13. Governing law</h2>
          <p>
            These Terms are governed by the laws applicable in the developer’s
            primary place of business, without regard to conflict-of-law rules,
            except that mandatory consumer protections in your country of
            residence continue to apply. Courts in that jurisdiction may have
            exclusive venue for disputes, unless mandatory law gives you the
            right to bring claims elsewhere.
          </p>

          <h2>14. Miscellaneous</h2>
          <ul>
            <li>
              If any provision is unenforceable, the rest remains in effect.
            </li>
            <li>
              Failure to enforce a provision is not a waiver.
            </li>
            <li>
              These Terms describe our optional purchase and related services;
              the software licenses continue to govern covered materials.
            </li>
            <li>
              Privacy practices are described in our
              <a href="/privacy/">Privacy Policy</a>.
            </li>
          </ul>

          <div class="contact">
            <h2>15. Contact</h2>
            <p>Questions about these Terms:</p>
            <p>
              Email:
              <a href="mailto:{{CONTACT_EMAIL}}">{{CONTACT_EMAIL}}</a><br />
              Subject line suggestion: <strong>lemonGba Terms</strong>
            </p>
            <p class="meta" style="margin-bottom: 0">
              Related:
              <a href="/privacy/">Privacy Policy</a> ·
              <a href="/data-deletion/">Data deletion</a>
            </p>
          </div>
        </div>"""


HOME = r"""        <section class="hero">
          <p class="eyebrow">Legal</p>
          <h1>lemonGba policies</h1>
          <p class="lead">
            Official Privacy Policy, Terms of Service, and data deletion
            instructions for the lemonGba app. Used by the Google Play listing
            and in-app Settings links.
          </p>
        </section>

        <div class="doc-list">
          <a class="doc-btn" href="/privacy/">
            <span class="doc-btn-body">
              <span class="doc-btn-title">Privacy Policy</span>
              <span class="doc-btn-desc"
                >How we handle data and purchases on your device.</span
              >
            </span>
            <span class="doc-btn-go">Open</span>
          </a>
          <a class="doc-btn" href="/terms/">
            <span class="doc-btn-body">
              <span class="doc-btn-title">Terms of Service</span>
              <span class="doc-btn-desc"
                >Rules for using the app, ROMs, Pro, and liability.</span
              >
            </span>
            <span class="doc-btn-go">Open</span>
          </a>
          <a class="doc-btn" href="/data-deletion/">
            <span class="doc-btn-body">
              <span class="doc-btn-title">Delete your data</span>
              <span class="doc-btn-desc"
                >How to clear on-device data and request deletion.</span
              >
            </span>
            <span class="doc-btn-go">Open</span>
          </a>
        </div>"""


def _write(path: Path, html: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(html, encoding="utf-8", newline="\n")


def main() -> None:
    if not CONFIG.is_file():
        raise SystemExit(
            "Missing hosting/site_config.json; copy site_config.json.example "
            "and set CONTACT_EMAIL before building or deploying."
        )
    contact_email = json.loads(CONFIG.read_text(encoding="utf-8")).get("CONTACT_EMAIL", "")
    if not re.fullmatch(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", contact_email):
        raise SystemExit("Set a valid CONTACT_EMAIL in hosting/site_config.json.")
    safe_email = escape(contact_email, quote=True)
    pages = {
        BASE / "index.html": wrap(
            "lemonGba · Legal",
            "Legal documents for lemonGba — Privacy, Terms, and data deletion.",
            "",
            HOME,
        ),
        BASE / "privacy" / "index.html": wrap(
            "Privacy Policy · lemonGba",
            "Privacy Policy for lemonGba — how we handle data and purchases.",
            "privacy",
            PRIVACY,
        ),
        BASE / "terms" / "index.html": wrap(
            "Terms of Service · lemonGba",
            "Terms of Service for lemonGba — rules for using the emulator app.",
            "terms",
            TERMS,
        ),
        BASE / "data-deletion" / "index.html": wrap(
            "Data deletion · lemonGba",
            "How to request deletion of your data for the lemonGba app by thezello.",
            "deletion",
            DELETION,
        ),
    }
    for path, html in pages.items():
        _write(path, html.replace("{{CONTACT_EMAIL}}", safe_email))

    css_ref = f"styles.css?v={CSS_VERSION}"
    for path in pages:
        text = path.read_text(encoding="utf-8")
        assert "topbar-inner" in text, path
        assert css_ref in text, path
        assert 'class="panel"' not in text, path
    terms = (BASE / "terms" / "index.html").read_text(encoding="utf-8")
    assert 'class="prose"' in terms
    deletion = (BASE / "data-deletion" / "index.html").read_text(encoding="utf-8")
    assert "lemonGba" in deletion
    assert "thezello" in deletion
    assert safe_email in deletion
    home = (BASE / "index.html").read_text(encoding="utf-8")
    assert "doc-btn" in home
    assert "data-deletion" in home
    print(f"ok: home + privacy + terms + data-deletion (css v={CSS_VERSION})")


if __name__ == "__main__":
    main()
