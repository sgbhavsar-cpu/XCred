import 'package:dio/dio.dart';

import 'api_response.dart';

/// Thin wrapper around [Dio] that unwraps XCred's `ApiResponse<T>` envelope and turns
/// `success: false` / network failures into a single [ApiException] type screens can
/// catch uniformly. Auth (JWT attach, 401 refresh) is added via interceptors in
/// core/providers/core_providers.dart, not here — this class only knows about shape.
class ApiClient {
  ApiClient(this._dio);
  final Dio _dio;

  Dio get dio => _dio;

  Future<T> get<T>(
    String path,
    T Function(dynamic json) fromData, {
    Map<String, dynamic>? query,
  }) =>
      _unwrap(_dio.get(path, queryParameters: query), fromData);

  Future<T> post<T>(
    String path,
    T Function(dynamic json) fromData, {
    Object? data,
  }) =>
      _unwrap(_dio.post(path, data: data), fromData);

  Future<T> put<T>(
    String path,
    T Function(dynamic json) fromData, {
    Object? data,
  }) =>
      _unwrap(_dio.put(path, data: data), fromData);

  Future<T> delete<T>(
    String path,
    T Function(dynamic json) fromData,
  ) =>
      _unwrap(_dio.delete(path), fromData);

  Future<T> _unwrap<T>(
    Future<Response> request,
    T Function(dynamic json) fromData,
  ) async {
    try {
      final response = await request;
      final envelope = ApiResponse<T>.fromJson(
        response.data as Map<String, dynamic>,
        fromData,
      );
      if (!envelope.success || envelope.data == null) {
        final error = envelope.error;
        throw ApiException(
          code: error?.code ?? 'UNKNOWN',
          message: error?.message ?? 'Request failed.',
        );
      }
      return envelope.data as T;
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map<String, dynamic> && body['error'] != null) {
        final error = ApiError.fromJson(body['error'] as Map<String, dynamic>);
        throw ApiException(code: error.code, message: error.message);
      }
      throw ApiException(
        code: 'NETWORK_ERROR',
        message: e.message ?? 'Could not reach the server.',
      );
    }
  }
}

/// No-op passthrough for endpoints whose `data` is already the right shape (e.g. raw
/// `Map<String, dynamic>` before a typed model exists yet).
T identityFromData<T>(dynamic json) => json as T;
