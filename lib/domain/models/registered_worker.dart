import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'registered_worker.g.dart';

@HiveType(typeId: 1)
class RegisteredWorker extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<List<double>> faceEmbeddings;

  @HiveField(2)
  String id;

  @HiveField(3)
  String cedula;

  @HiveField(4)
  String cargo;

  @HiveField(5)
  bool enabled;

  RegisteredWorker({
    required this.name,
    required this.faceEmbeddings,
    this.cedula = '',
    this.cargo = '',
    this.enabled = true,
    String? id,
  }) : this.id = id ?? const Uuid().v4();
}
