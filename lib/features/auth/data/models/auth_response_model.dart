import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/auth_response.dart';
import 'user_model.dart';

part 'auth_response_model.g.dart';

/// Auth Response Model (Data Layer)
@JsonSerializable()
class AuthResponseModel {
  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  final UserModel user;

  AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  /// From JSON
  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseModelFromJson(json);

  /// To JSON
  Map<String, dynamic> toJson() => _$AuthResponseModelToJson(this);

  /// Convert Model to Entity
  AuthResponse toEntity() {
    return AuthResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user.toEntity(),
    );
  }
}
