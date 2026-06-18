import 'package:flint_dart/auth.dart';
import 'package:flint_dart/flint_dart.dart';
import 'package:backend/models/user_model.dart';
import 'package:backend/core/api_response.dart';
import 'package:backend/services/auth_context_service.dart';

class AuthController extends Controller {
  final _authContextService = AuthContextService();

  Future<Response> register() async {
    try {
      final body = await req.json();
      await Validator.validate(body, {
        "email": "required|email",
        "first_name": "required|string",
        "last_name": "required|string",
        "username": "required|string",
        "password": "required|string"
      });
      body["password_hash"] = Hashing().hash(body["password"]);
      body.remove("password");
      body["company_id"] = body["company_id"] ?? 1;
      body["role_id"] = body["role_id"] ?? 1;
      body["status"] = body["status"] ?? "active";
      final User? user = await User().create(body);

      return res.json(ApiResponse.success(
        data: user?.toMap(),
        message: 'User registered successfully',
      ));
    } catch (e) {
      return res.status(422).json(
        ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: e.toString(),
        ),
      );
    }
  }

  Future<Response> login() async {
    try {
      var body = await req.json();

      await Validator.validate(
          body, {"email": "required|string", "password": "required|string"});
      final dbReadyResponse = await _ensureDatabaseReady();
      if (dbReadyResponse != null) return dbReadyResponse;

      final authResult = await Auth.loginWithTokens(
        body['email'],
        body["password"],
        ipAddress: req.ipAddress,
        userAgent: req.headers['user-agent'] ?? req.headers['User-Agent'],
      );

      final user = authResult['user'] as Map<String, dynamic>;
      await DB.query(
        'UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = ?',
        positionalParams: [user['id']],
      );
      final authContext = await _authContextService.fromUserId(user['id']);

      return res.json(ApiResponse.success(
        data: {
          "access_token": authResult['accessToken'] ?? authResult['token'],
          if (authResult['refreshToken'] != null)
            "refresh_token": authResult['refreshToken'],
          "user": authContext?['user'] ?? user,
          "permissions": authContext?['permissions'] ?? [],
        },
        message: 'Login successful',
      ));
    } on ValidationException catch (e) {
      return res.status(422).json(ApiResponse.error(
        code: 'VALIDATION_ERROR',
        message: 'Validation failed',
        details: e.errors,
      ));
    } catch (e) {
      return res.status(401).json(ApiResponse.error(
        code: 'UNAUTHENTICATED',
        message: e.toString(),
      ));
    }
  }

  Future<Response?> _ensureDatabaseReady() async {
    if (DB.isConnected) return null;

    try {
      await DB.autoConnect().timeout(const Duration(seconds: 10));
      return null;
    } catch (_) {
      return res.status(503).json(ApiResponse.error(
        code: 'DATABASE_UNAVAILABLE',
        message:
            'Database connection failed. Check backend .env DB credentials and run migrations/seeders.',
      ));
    }
  }

  Future<Response> me() async {
    final authContext =
        await _authContextService.fromBearerToken(req.bearerToken);
    if (authContext == null) {
      return res.status(401).json(ApiResponse.error(
        code: 'UNAUTHENTICATED',
        message: 'Authentication required',
      ));
    }

    return res.json(ApiResponse.success(
      data: authContext,
      message: 'Current user retrieved successfully',
    ));
  }

  Future<Response> refresh() async {
    final body = await req.json();
    final refreshToken = body['refresh_token']?.toString();
    if (refreshToken == null || refreshToken.isEmpty) {
      return res.status(422).json(ApiResponse.error(
        code: 'VALIDATION_ERROR',
        message: 'refresh_token is required.',
      ));
    }

    final result = await Auth.refreshAccessToken(
      refreshToken,
      ipAddress: req.ipAddress,
      userAgent: req.headers['user-agent'] ?? req.headers['User-Agent'],
    );

    if (result == null) {
      return res.status(401).json(ApiResponse.error(
        code: 'UNAUTHENTICATED',
        message: 'Invalid or expired refresh token.',
      ));
    }

    return res.json(ApiResponse.success(
      data: {
        'access_token': result['accessToken'] ?? result['token'],
        if (result['refreshToken'] != null)
          'refresh_token': result['refreshToken'],
      },
      message: 'Token refreshed successfully',
    ));
  }

  Future<Response> forgotPassword() async {
    final body = await req.json();
    final email = body['email']?.toString();
    if (email == null || email.isEmpty) {
      return res.status(422).json(ApiResponse.error(
        code: 'VALIDATION_ERROR',
        message: 'email is required.',
      ));
    }

    await Auth.generatePasswordResetToken(email);
    return res.json(ApiResponse.success(
      message:
          'If the email exists, a password reset instruction has been generated.',
    ));
  }

  Future<Response> resetPassword() async {
    final body = await req.json();
    final token = body['token']?.toString();
    final password = body['password']?.toString();
    if (token == null || token.isEmpty || password == null || password.isEmpty) {
      return res.status(422).json(ApiResponse.error(
        code: 'VALIDATION_ERROR',
        message: 'token and password are required.',
      ));
    }

    final changed = await Auth.resetPassword(
      token: token,
      newPassword: password,
    );
    if (!changed) {
      return res.status(422).json(ApiResponse.error(
        code: 'VALIDATION_ERROR',
        message: 'Invalid or expired password reset token.',
      ));
    }

    return res.json(ApiResponse.success(
      message: 'Password reset successfully',
    ));
  }

  Future<Response> logout() async {
    final body = await req.json();
    final refreshToken = body['refresh_token']?.toString();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await Auth.revokeRefreshToken(refreshToken);
    }

    return res.json(ApiResponse.success(message: 'Logout successful'));
  }

  Future<Response> loginWithGoogle() async {
    try {
      final body = await req.json();

      // Check if idToken or code is present and validate
      await Validator.validate(body,
          {"idToken": "string", "code": "string", "callbackPath": "string"});

      // Pass either idToken or code to the Auth class
      final Map<String, dynamic> authResult = await Auth.loginWithGoogle(
        idToken: body['idToken'],
        code: body['code'],
        callbackPath: body['callbackPath'],
      );

      return res.json({
        "status": "success",
        "data": authResult,
      });
    } on ArgumentError catch (e) {
      return res.status(400).json({"status": "error", "message": e.message});
    } on ValidationException catch (e) {
      return res.status(400).json({"status": "error", "message": e.errors});
    } catch (e) {
      return res.status(401).json({"status": "error", "message": e.toString()});
    }
  }

  Future<Response> update() async {
    return res.send('Updating item ${req.params['id']}');
  }

  Future<Response> delete() async {
    return res.send('Deleting item ${req.params['id']}');
  }
}
