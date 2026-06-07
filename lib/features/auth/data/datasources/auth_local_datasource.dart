import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

/// Auth Local Data Source Interface
abstract class AuthLocalDataSource {
  Future<void> cacheTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<String?> getAccessToken();

  Future<String?> getRefreshToken();

  Future<void> cacheUser(UserModel user);

  Future<UserModel?> getUser();

  Future<void> cacheTenantInfo({
    required String tenantId,
    String? tenantSchema,
  });

  Future<String?> getTenantId();

  Future<void> clearAll();

  Future<bool> hasToken();

  /// Guarda los datos NO sensibles del último login exitoso
  /// (subdomain + email) para precargar el formulario al volver a
  /// abrir la app o tras un logout. La contraseña NUNCA se guarda
  /// — solo identificadores.
  Future<void> cacheLastLogin({
    required String subdomain,
    required String email,
  });

  /// Devuelve `(subdomain, email)` del último login exitoso, o
  /// `(null, null)` si nunca se logueó.
  Future<({String? subdomain, String? email})> getLastLogin();

  /// Borra solo la sesión (tokens + user + tenant) pero MANTIENE
  /// `lastLogin` para sugerir el formulario al próximo intento.
  /// Usado por el logout normal.
  Future<void> clearSessionKeepingLastLogin();
}

/// Auth Local Data Source Implementation
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage? secureStorage;
  final SharedPreferences? sharedPreferences;

  // Use SharedPreferences on platforms where flutter_secure_storage is unsupported
  // (web, macOS without keychain entitlements). Use SecureStorage on iOS/Android.
  final bool _useMacOSFallback = kIsWeb || (!kIsWeb && Platform.isMacOS);

  AuthLocalDataSourceImpl({
    this.secureStorage,
    this.sharedPreferences,
  });

  @override
  Future<void> cacheTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      if (_useMacOSFallback && sharedPreferences != null) {
        await sharedPreferences!.setString(ApiConstants.accessTokenKey, accessToken);
        await sharedPreferences!.setString(ApiConstants.refreshTokenKey, refreshToken);
      } else if (secureStorage != null) {
        await secureStorage!.write(
          key: ApiConstants.accessTokenKey,
          value: accessToken,
        );
        await secureStorage!.write(
          key: ApiConstants.refreshTokenKey,
          value: refreshToken,
        );
      }
    } catch (e) {
      throw CacheException('Failed to cache tokens: ${e.toString()}');
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      if (_useMacOSFallback && sharedPreferences != null) {
        return sharedPreferences!.getString(ApiConstants.accessTokenKey);
      } else if (secureStorage != null) {
        return await secureStorage!.read(key: ApiConstants.accessTokenKey);
      }
      return null;
    } catch (e) {
      throw CacheException('Failed to get access token');
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      if (_useMacOSFallback && sharedPreferences != null) {
        return sharedPreferences!.getString(ApiConstants.refreshTokenKey);
      } else if (secureStorage != null) {
        return await secureStorage!.read(key: ApiConstants.refreshTokenKey);
      }
      return null;
    } catch (e) {
      throw CacheException('Failed to get refresh token');
    }
  }

  @override
  Future<void> cacheUser(UserModel user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      if (_useMacOSFallback && sharedPreferences != null) {
        await sharedPreferences!.setString(ApiConstants.userKey, userJson);
      } else if (secureStorage != null) {
        await secureStorage!.write(
          key: ApiConstants.userKey,
          value: userJson,
        );
      }
    } catch (e) {
      throw CacheException('Failed to cache user: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getUser() async {
    try {
      String? userJson;
      if (_useMacOSFallback && sharedPreferences != null) {
        userJson = sharedPreferences!.getString(ApiConstants.userKey);
      } else if (secureStorage != null) {
        userJson = await secureStorage!.read(key: ApiConstants.userKey);
      }

      if (userJson != null) {
        return UserModel.fromJson(jsonDecode(userJson));
      }
      return null;
    } catch (e) {
      throw CacheException('Failed to get user');
    }
  }

  @override
  Future<void> cacheTenantInfo({
    required String tenantId,
    String? tenantSchema,
  }) async {
    try {
      if (_useMacOSFallback && sharedPreferences != null) {
        await sharedPreferences!.setString(ApiConstants.tenantIdKey, tenantId);
        if (tenantSchema != null) {
          await sharedPreferences!.setString(ApiConstants.tenantSchemaKey, tenantSchema);
        }
      } else if (secureStorage != null) {
        await secureStorage!.write(
          key: ApiConstants.tenantIdKey,
          value: tenantId,
        );
        if (tenantSchema != null) {
          await secureStorage!.write(
            key: ApiConstants.tenantSchemaKey,
            value: tenantSchema,
          );
        }
      }
    } catch (e) {
      throw CacheException('Failed to cache tenant info');
    }
  }

  @override
  Future<String?> getTenantId() async {
    try {
      if (_useMacOSFallback && sharedPreferences != null) {
        return sharedPreferences!.getString(ApiConstants.tenantIdKey);
      } else if (secureStorage != null) {
        return await secureStorage!.read(key: ApiConstants.tenantIdKey);
      }
      return null;
    } catch (e) {
      throw CacheException('Failed to get tenant ID');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      if (_useMacOSFallback && sharedPreferences != null) {
        await sharedPreferences!.clear();
      } else if (secureStorage != null) {
        await secureStorage!.deleteAll();
      }
    } catch (e) {
      throw CacheException('Failed to clear storage');
    }
  }

  @override
  Future<bool> hasToken() async {
    try {
      final token = await getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> cacheLastLogin({
    required String subdomain,
    required String email,
  }) async {
    try {
      // `lastLogin` se guarda SIEMPRE en SharedPreferences (no en
      // SecureStorage) — son datos no sensibles que sobreviven al
      // logout y se usan para autocomplete del form. Si quedaran en
      // SecureStorage los borraría `clearAll` al fallar un refresh.
      final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.lastLoginSubdomainKey, subdomain);
      await prefs.setString(ApiConstants.lastLoginEmailKey, email);
    } catch (e) {
      // No es crítico — el peor caso es que el próximo login no
      // sugiera los valores. No bloqueamos el flujo.
    }
  }

  @override
  Future<({String? subdomain, String? email})> getLastLogin() async {
    try {
      final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
      return (
        subdomain: prefs.getString(ApiConstants.lastLoginSubdomainKey),
        email: prefs.getString(ApiConstants.lastLoginEmailKey),
      );
    } catch (e) {
      return (subdomain: null, email: null);
    }
  }

  @override
  Future<void> clearSessionKeepingLastLogin() async {
    // Borra tokens + user + tenant. NO toca `lastLogin*` para que el
    // próximo login pueda sugerir los valores.
    try {
      if (_useMacOSFallback && sharedPreferences != null) {
        await sharedPreferences!.remove(ApiConstants.accessTokenKey);
        await sharedPreferences!.remove(ApiConstants.refreshTokenKey);
        await sharedPreferences!.remove(ApiConstants.userKey);
        await sharedPreferences!.remove(ApiConstants.tenantIdKey);
        await sharedPreferences!.remove(ApiConstants.tenantSchemaKey);
      } else if (secureStorage != null) {
        await secureStorage!.delete(key: ApiConstants.accessTokenKey);
        await secureStorage!.delete(key: ApiConstants.refreshTokenKey);
        await secureStorage!.delete(key: ApiConstants.userKey);
        await secureStorage!.delete(key: ApiConstants.tenantIdKey);
        await secureStorage!.delete(key: ApiConstants.tenantSchemaKey);
      }
    } catch (e) {
      throw CacheException('Failed to clear session');
    }
  }
}
