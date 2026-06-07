// lib/features/tables/domain/usecases/create_table_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/table.dart';
import '../repositories/table_repository.dart';

/// Use case para crear una nueva mesa
class CreateTableUseCase {
  final TableRepository repository;

  CreateTableUseCase(this.repository);

  Future<Either<Failure, RestaurantTable>> call({
    required Map<String, dynamic> tableData,
  }) async {
    return await repository.createTable(
      tableNumber: tableData['table_number'] as String,
      name: tableData['name'] as String?,
      capacity: tableData['capacity'] as int,
      minCapacity: tableData['min_capacity'] as int?,
      tableType: tableData['table_type'] != null
          ? TableType.fromString(tableData['table_type'] as String)
          : null,
      shape: tableData['shape'] != null
          ? TableShape.fromString(tableData['shape'] as String)
          : null,
      zone: tableData['zone'] as String?,
      section: tableData['section'] as String?,
      positionX: tableData['position_x'] != null
          ? (tableData['position_x'] as double).toInt()
          : null,
      positionY: tableData['position_y'] != null
          ? (tableData['position_y'] as double).toInt()
          : null,
      width: tableData['width'] as double?,
      height: tableData['height'] as double?,
      metadata: tableData['metadata'] as Map<String, dynamic>?,
    );
  }
}
