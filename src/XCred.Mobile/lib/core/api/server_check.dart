import 'package:dio/dio.dart';

/// Proves [url] points at a real XCred API: an unauthenticated `GET /api/dashboard` must be
/// answered with 401 (a 200 would be unusual but still proves reachability). Anything else —
/// timeout, DNS failure, a 404 from some other web server — means "not an XCred server".
Future<bool> isXCredServer(String url, {Dio? dio}) async {
  final client = dio ??
      Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
  try {
    await client.get('$url/api/dashboard');
    return true;
  } on DioException catch (e) {
    return e.response?.statusCode == 401;
  } catch (_) {
    return false;
  }
}
