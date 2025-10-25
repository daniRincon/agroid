import 'package:viser/domain/models/registered_worker.dart';
import 'package:viser/domain/models/work_log.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) {
      print('📦 Base de datos ya inicializada, omitiendo...');
      return;
    }

    try {
      print('📦 Paso 1: Inicializando Hive Flutter...');
      // 1. Inicializar Hive en el directorio de la app
      await Hive.initFlutter();
      print('✅ Hive inicializado');

      // 2. Registrar los adaptadores generados
      print('📦 Paso 2: Registrando adaptadores...');
      if (!Hive.isAdapterRegistered(WorkLogAdapter().typeId)) {
        Hive.registerAdapter(WorkLogAdapter());
        print('✅ Adaptador WorkLog registrado');
      }
      if (!Hive.isAdapterRegistered(RegisteredWorkerAdapter().typeId)) {
        Hive.registerAdapter(RegisteredWorkerAdapter());
        print('✅ Adaptador RegisteredWorker registrado');
      }

      // 3. Intentar abrir o recrear las cajas
      print('📦 Paso 3: Abriendo cajas...');
      bool needsRecreation = false;
      
      // Intentar abrir work_logs
      try {
        print('📦 Abriendo work_logs...');
        await Hive.openBox<WorkLog>('work_logs');
        print('✅ work_logs abierto');
      } catch (e) {
        print('❌ Error al abrir work_logs: $e');
        needsRecreation = true;
        try {
          await Hive.deleteBoxFromDisk('work_logs');
          print('🗑️ work_logs eliminado');
        } catch (deleteError) {
          print('❌ Error al eliminar work_logs: $deleteError');
        }
      }

      // Intentar abrir registered_workers
      try {
        print('📦 Abriendo registered_workers...');
        await Hive.openBox<RegisteredWorker>('registered_workers');
        print('✅ registered_workers abierto');
      } catch (e) {
        print('❌ Error al abrir registered_workers: $e');
        needsRecreation = true;
        try {
          await Hive.deleteBoxFromDisk('registered_workers');
          print('🗑️ registered_workers eliminado');
        } catch (deleteError) {
          print('❌ Error al eliminar registered_workers: $deleteError');
        }
      }

      // Si hubo errores, intentar abrir nuevamente las cajas eliminadas
      if (needsRecreation) {
        print('🔄 Recreando cajas...');
        if (!Hive.isBoxOpen('work_logs')) {
          await Hive.openBox<WorkLog>('work_logs');
          print('✅ work_logs recreado');
        }
        if (!Hive.isBoxOpen('registered_workers')) {
          await Hive.openBox<RegisteredWorker>('registered_workers');
          print('✅ registered_workers recreado');
        }
      }

      _isInitialized = true;
      print('✅ Base de datos completamente inicializada');
    } catch (e) {
      print('❌ Error crítico inicializando la base de datos: $e');
      rethrow;
    }
  }

  Future<void> _deleteBoxes() async {
    try {
      await Future.wait([
        Hive.deleteBoxFromDisk('work_logs'),
        Hive.deleteBoxFromDisk('registered_workers'),
      ]);
    } catch (e) {
      print('Error al eliminar las cajas: $e');
      rethrow;
    }
  }

  Future<void> clearDatabase() async {
    await _ensureInitialized();
    try {
      final workLogsBox = Hive.box<WorkLog>('work_logs');
      final workersBox = Hive.box<RegisteredWorker>('registered_workers');

      await Future.wait([
        workLogsBox.clear(),
        workersBox.clear(),
      ]);
    } catch (e) {
      print('Error al limpiar la base de datos: $e');
      // Intentar eliminar y recrear las cajas si la limpieza falla
      await _deleteBoxes();
      await init();
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  // --- Métodos para RegisteredWorker ---

  Future<void> addWorker(RegisteredWorker worker) async {
    print('Agregando trabajador: ' + worker.name);
    final box = await Hive.openBox<RegisteredWorker>('registered_workers');
    await box.add(worker);
    print('Trabajador agregado correctamente. Total trabajadores: ' + box.length.toString());
  }

  Future<List<RegisteredWorker>> getAllWorkers() async {
    await _ensureInitialized();
    final box = Hive.box<RegisteredWorker>('registered_workers');
    return box.values.toList();
  }

  Future<void> deleteWorker(String id) async {
    await _ensureInitialized();
    final box = Hive.box<RegisteredWorker>('registered_workers');
    
    // Buscar el trabajador por ID y eliminar por clave de Hive
    final workers = box.values.toList();
    for (int i = 0; i < workers.length; i++) {
      if (workers[i].id == id) {
        final key = box.keyAt(i);
        await box.delete(key);
        break;
      }
    }
  }

  Future<void> updateWorker(RegisteredWorker worker) async {
    await _ensureInitialized();
    await worker.save();
  }

  // --- Métodos para WorkLog ---

  Future<void> addWorkLog(WorkLog log) async {
    await _ensureInitialized();
    final box = Hive.box<WorkLog>('work_logs');
    await box.add(log); // add() usa una clave autoincremental
  }

  Future<WorkLog?> getLastLogForWorker(String workerId) async {
    await _ensureInitialized();
    final box = Hive.box<WorkLog>('work_logs');
    final logs = box.values.where((log) => log.workerId == workerId).toList();
    if (logs.isEmpty) return null;
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs.first;
  }

  Future<List<WorkLog>> getAllWorkLogs() async {
    await _ensureInitialized();
    final box = Hive.box<WorkLog>('work_logs');
    return box.values.toList();
  }

  Future<List<WorkLog>> getUnsyncedLogs() async {
    await _ensureInitialized();
    final box = Hive.box<WorkLog>('work_logs');
    return box.values.where((log) => !log.isSynced).toList();
  }

  Future<void> markLogAsSynced(WorkLog log) async {
    await _ensureInitialized();
    log.isSynced = true;
    await log.save();
  }
}
