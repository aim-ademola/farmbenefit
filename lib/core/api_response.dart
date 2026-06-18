class ApiResponse {
  static Map<String, dynamic> success({
    Object? data,
    String message = 'Operation completed',
  }) {
    return {
      'success': true,
      'data': data ?? {},
      'message': message,
    };
  }

  static Map<String, dynamic> error({
    required String code,
    required String message,
    Object? details,
  }) {
    return {
      'success': false,
      'error': {
        'code': code,
        'message': message,
        'details': details ?? {},
      },
    };
  }
}
