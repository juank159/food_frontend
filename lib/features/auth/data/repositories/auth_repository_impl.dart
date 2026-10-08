import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/auth_response.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

/// Auth Repository Implementation
/// Implements the domain repository contract
/// Handles data flow between remote and local sources
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, AuthResponse>> login({
    required String email,
    required String password,
    required String tenantSubdomain,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.login(
          email: email,
          password: password,
          tenantSubdomain: tenantSubdomain,
        );

        // Cache tokens and user data
        await localDataSource.cacheTokens(
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
        );
        await localDataSource.cacheUser(result.user);
        await localDataSource.cacheTenantInfo(
          tenantId: result.user.tenantId,
        );

        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(InvalidCredentialsFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, AuthResponse>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    required String tenantSubdomain,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.register(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
          tenantSubdomain: tenantSubdomain,
        );

        // Cache tokens and user data
        await localDataSource.cacheTokens(
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
        );
        await localDataSource.cacheUser(result.user);
        await localDataSource.cacheTenantInfo(
          tenantId: result.user.tenantId,
        );

        return Right(result.toEntity());
      } on ConflictException catch (e) {
        return Left(ConflictFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> signUp({
    required String businessName,
    required String businessType,
    required String subdomain,
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.signUp(
          businessName: businessName,
          businessType: businessType,
          subdomain: subdomain,
          email: email,
          password: password,
          fullName: fullName,
          phoneNumber: phoneNumber,
        );
        return const Right(null);
      } on ConflictException catch (e) {
        return Left(ConflictFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, AuthResponse>> confirmSignup({
    required String email,
    required String code,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result =
            await remoteDataSource.confirmSignup(email: email, code: code);

        await localDataSource.cacheTokens(
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
        );
        await localDataSource.cacheUser(result.user);
        await localDataSource.cacheTenantInfo(
          tenantId: result.user.tenantId,
        );

        return Right(result.toEntity());
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> resendSignupCode({
    required String email,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.resendSignupCode(email: email);
        return const Right(null);
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> forgotPassword({required String email}) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.forgotPassword(email: email);
        return const Right(null);
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.resetPassword(
          email: email,
          code: code,
          newPassword: newPassword,
        );
        return const Right(null);
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> verifyEmail({
    required String email,
    required String code,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.verifyEmail(email: email, code: code);
        return const Right(null);
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        return const Right(null);
      } on UnauthorizedException catch (e) {
        return Left(UnauthorizedFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      // Try to get user from cache first
      final cachedUser = await localDataSource.getUser();
      if (cachedUser != null) {
        return Right(cachedUser.toEntity());
      }

      // If not in cache and we have network, fetch from server
      if (await networkInfo.isConnected) {
        final token = await localDataSource.getAccessToken();
        if (token == null) {
          return const Left(UnauthorizedFailure());
        }

        final result = await remoteDataSource.getCurrentUser(token);
        await localDataSource.cacheUser(result);

        return Right(result.toEntity());
      } else {
        return const Left(NetworkFailure());
      }
    } on UnauthorizedException {
      return const Left(TokenExpiredFailure());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, User>> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final cachedUser = await localDataSource.getUser();
      if (cachedUser == null) {
        return const Left(UnauthorizedFailure());
      }

      await remoteDataSource.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
      );

      // El backend confirmó el guardado — actualizamos el usuario en
      // caché con los mismos valores que le mandamos (no re-parseamos
      // su respuesta cruda, ver nota en el datasource).
      final updatedEntity = cachedUser.toEntity().copyWith(
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber,
          );
      await localDataSource.cacheUser(UserModel.fromEntity(updatedEntity));

      return Right(updatedEntity);
    } on UnauthorizedException {
      return const Left(TokenExpiredFailure());
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AuthResponse>> refreshToken() async {
    if (await networkInfo.isConnected) {
      try {
        final refreshToken = await localDataSource.getRefreshToken();
        if (refreshToken == null) {
          return const Left(UnauthorizedFailure());
        }

        final result = await remoteDataSource.refreshToken(refreshToken);

        // Update cached tokens
        await localDataSource.cacheTokens(
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
        );
        await localDataSource.cacheUser(result.user);

        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(TokenExpiredFailure());
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      final token = await localDataSource.getAccessToken();

      // Try to logout on server (optional)
      if (token != null && await networkInfo.isConnected) {
        await remoteDataSource.logout(token);
      }

      // Clear ONLY session (tokens + user + tenant). Mantenemos
      // `lastLogin` (subdomain + email no sensibles) para que la
      // próxima pantalla de login los precargue. Esto es la
      // expectativa del usuario: "cerrar sesión" no equivale a
      // "olvidar quién soy".
      await localDataSource.clearSessionKeepingLastLogin();

      return const Right(null);
    } catch (e) {
      await localDataSource.clearSessionKeepingLastLogin();
      return const Right(null);
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      return await localDataSource.hasToken();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await localDataSource.getAccessToken();
    } catch (e) {
      return null;
    }
  }
}
