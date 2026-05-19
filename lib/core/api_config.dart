/// Vercel API base URL.
/// 部署后替换为你的 Vercel 项目地址，例如：
///   https://expense-tracker-api.vercel.app
/// 开发环境可指向本地：
///   http://localhost:3000
class ApiConfig {
  ApiConfig._();

  /// 目前指向占位符，部署 Vercel 项目后填入真实 URL
  /// 示例：https://expense-tracker-api.vercel.app
  static const String baseUrl = 'https://your-vercel-project.vercel.app';
}
