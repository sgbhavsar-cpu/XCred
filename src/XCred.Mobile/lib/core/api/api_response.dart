// Mirrors XCred.Core.DTOs.Common.ApiResponse<T> — every XCred endpoint responds with this
// envelope, so every dio call is unwrapped through here rather than each screen re-parsing.
class ApiError {
  final String code;
  final String message;
  const ApiError({required this.code, required this.message});

  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
        code: json['code'] as String? ?? 'UNKNOWN',
        message: json['message'] as String? ?? 'Unknown error',
      );
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final ApiError? error;
  const ApiResponse({required this.success, this.data, this.error});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) fromData,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: json['data'] == null ? null : fromData(json['data']),
      error: json['error'] == null
          ? null
          : ApiError.fromJson(json['error'] as Map<String, dynamic>),
    );
  }
}

/// Thrown by [ApiClient] when the server responds with `success: false`, or on a
/// network-level failure. Screens catch this and show [message] directly — it's already
/// the user-facing text the backend chose.
class ApiException implements Exception {
  final String code;
  final String message;
  const ApiException({required this.code, required this.message});

  @override
  String toString() => 'ApiException($code): $message';
}
