import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/auth_response.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

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
