// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: json['id'] as String,
  email: json['email'] as String,
  firstName: json['first_name'] as String,
  lastName: json['last_name'] as String,
  phoneNumber: json['phone_number'] as String?,
  roleId: json['role_id'] as String,
  role: RoleModel.fromJson(json['role'] as Map<String, dynamic>),
  tenantId: json['tenant_id'] as String,
  isActive: json['is_active'] as bool? ?? false,
  createdAt: json['created_at'] as String,
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'phone_number': instance.phoneNumber,
  'role_id': instance.roleId,
  'role': instance.role,
  'tenant_id': instance.tenantId,
  'is_active': instance.isActive,
  'created_at': instance.createdAt,
};

RoleModel _$RoleModelFromJson(Map<String, dynamic> json) => RoleModel(
  id: json['id'] as String,
  name: json['name'] as String,
  code: json['code'] as String?,
  permissions: json['permissions'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$RoleModelToJson(RoleModel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'code': instance.code,
  'permissions': instance.permissions,
};
