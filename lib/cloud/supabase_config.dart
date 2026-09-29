enum AppEnvironment { production, uat }

class SupabaseConfig {
  // Enabled only after valid Google Cloud OAuth credentials are configured in
  // both Supabase projects.
  static const googleOAuthEnabled = false;

  static const _uatUrl = 'https://yvyvbjtgfmpvvbnmzinq.supabase.co';
  static const _uatPublishableKey =
      'sb_publishable_0rPCSgL94fhHr9gVgAzqQQ_FHuFtwvD';

  static const _productionUrl = 'https://poftsyskfuyeznbzxpow.supabase.co';
  static const _productionPublishableKey =
      'sb_publishable_n4Hudhh3uiUNxaYLkV8XKQ_UWUbIrB0';

  /// Cloudflare's pages.dev host and local web builds are the UAT surface.
  /// The custom domain and packaged apps use the clean production project.
  static AppEnvironment environmentForHost([String? host]) {
    final normalized = (host ?? Uri.base.host).trim().toLowerCase();
    final isUat = normalized == 'facility-billing-management.pages.dev' ||
        normalized.endsWith('.facility-billing-management.pages.dev') ||
        normalized == 'localhost' ||
        normalized == '127.0.0.1';
    return isUat ? AppEnvironment.uat : AppEnvironment.production;
  }

  static bool isUatHost([String? host]) =>
      environmentForHost(host) == AppEnvironment.uat;

  static AppEnvironment get environment => environmentForHost();

  static String get environmentLabel =>
      environment == AppEnvironment.uat ? 'UAT · TEST DATA' : 'PRODUCTION';

  static String get projectRef => environment == AppEnvironment.uat
      ? 'yvyvbjtgfmpvvbnmzinq'
      : 'poftsyskfuyeznbzxpow';

  static String get url => isUatHost() ? _uatUrl : _productionUrl;

  static String get publishableKey =>
      isUatHost() ? _uatPublishableKey : _productionPublishableKey;

  /// Keep email confirmation inside the environment where signup started.
  /// This prevents a production owner from being redirected into UAT.
  static String authRedirectUrlForHost(String host) => isUatHost(host)
      ? 'https://facility-billing-management.pages.dev/'
      : 'https://homeops360.app/';

  static String get authRedirectUrl => authRedirectUrlForHost(Uri.base.host);
}
