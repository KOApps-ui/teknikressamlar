class AppVersion {
  static const String version = '1.0.3';
  static const int buildNumber = 3;
  static final DateTime buildDate = DateTime.utc(2026, 10, 26, 21, 15);

  static const String githubOwner = 'KOApps-ui';
  static const String githubRepo = 'teknikressamlar';
  static const String releaseTag = 'APK';
  static const String releasePageUrl =
      'https://github.com/$githubOwner/$githubRepo/releases/tag/$releaseTag';
  static const String apiUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/tags/$releaseTag';
  static const String latestApiUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
}
