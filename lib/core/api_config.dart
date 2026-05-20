/// Vercel API base URL — injected at build time via `--dart-define`.
///
/// ```bash
/// flutter build apk --release \
///   --dart-define=API_BASE_URL=https://your-project.vercel.app
///
/// flutter build ios --release \
///   --dart-define=API_BASE_URL=https://your-project.vercel.app
/// ```
///
/// Local dev (Vercel CLI `vercel dev`):
/// ```bash
/// flutter run --dart-define=API_BASE_URL=http://localhost:3000
/// ```
class ApiConfig {
  ApiConfig._();

  /// Default matches production Vercel deployment; override per build/flavor.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://expensetracker-two-ashen.vercel.app',
  );
}
