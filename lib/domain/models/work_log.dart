import 'package:hive/hive.dart';

part 'work_log.g.dart';

@HiveType(typeId: 0)
class WorkLog extends HiveObject {
  @HiveField(0)
  final String workerName;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String logType; // "entrada" o "salida"

  @HiveField(3)
  bool isSynced;

  WorkLog({
    required this.workerName,
    required this.timestamp,
    required this.logType,
    this.isSynced = false,
  });
}
