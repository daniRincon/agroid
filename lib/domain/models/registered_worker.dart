import 'package:hive/hive.dart';

part 'registered_worker.g.dart';

@HiveType(typeId: 1)
class RegisteredWorker extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final List<double> embedding;

  RegisteredWorker({
    required this.name,
    required this.embedding,
  });
}
