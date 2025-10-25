import 'package:hive/hive.dart';

part 'work_log.g.dart';

@HiveType(typeId: 0)
class WorkLog extends HiveObject {
  @HiveField(0)
  final String workerId;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final bool isEntry;

  @HiveField(3)
  bool isSynced;

  WorkLog({
    required this.workerId,
    required this.timestamp,
    required this.isEntry,
    this.isSynced = false,
  });
}
