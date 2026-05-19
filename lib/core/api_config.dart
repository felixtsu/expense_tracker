/// Vercel API base URL.
/// 部署后替换为你的 Vercel 项目地址，例如：
///   https://expense-tracker-api.vercel.app
/// 开发环境可指向本地：
///   http://localhost:3000
class ApiConfig {
  ApiConfig._();

  /// Vercel serverless API — handles AI categorization + monthly insight
  /// Key lives in Vercel env vars, never shipped in the Flutter app
  static const String baseUrl = 'https://expense-tracker-api-lovat.vercel.app';
}
