import 'package:agroid/domain/models/registered_worker.dart';
import 'package:agroid/domain/models/work_log.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DatabaseService {
  Future<void> init() async {
    // 1. Inicializar Hive en el directorio de la app
    await Hive.initFlutter();

    // 2. Registrar los adaptadores generados
    Hive.registerAdapter(WorkLogAdapter());
    Hive.registerAdapter(RegisteredWorkerAdapter());

    // 3. Abrir las "cajas" (boxes) para almacenar los datos
    await Hive.openBox<WorkLog>('work_logs');
    await Hive.openBox<RegisteredWorker>('registered_workers');
  }

  // --- Métodos para RegisteredWorker ---

  Future<void> saveWorker(RegisteredWorker worker) async {
    final box = Hive.box<RegisteredWorker>('registered_workers');
    // Usamos el nombre como clave única, en minúsculas para evitar duplicados
    await box.put(worker.name.toLowerCase(), worker);
  }

  List<RegisteredWorker> getAllWorkers() {
    final box = Hive.box<RegisteredWorker>('registered_workers');
    return box.values.toList();
  }

  Future<void> deleteWorker(String name) async {
    final box = Hive.box<RegisteredWorker>('registered_workers');
    await box.delete(name.toLowerCase());
  }

  // --- Métodos para WorkLog ---

  Future<void> saveWorkLog(WorkLog log) async {
    final box = Hive.box<WorkLog>('work_logs');
    await box.add(log); // add() usa una clave autoincremental
  }

  List<WorkLog> getUnsyncedLogs() {
    final box = Hive.box<WorkLog>('work_logs');
    return box.values.where((log) => !log.isSynced).toList();
  }
}
