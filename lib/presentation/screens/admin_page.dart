import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:viser/domain/models/admin_api_config.dart';
import 'package:viser/domain/models/registered_worker.dart';
import 'package:viser/domain/models/work_log.dart';
import 'package:viser/domain/services/database_service.dart';
import 'package:viser/domain/services/face_recognition_service.dart';
import 'package:viser/presentation/screens/register_worker_page.dart';

// === COLORES CORPORATIVOS ===
const Color siomaRed = Color(0xFFC8102E);
const Color siomaWhite = Color(0xFFFFFFFF);
const Color siomaGray = Color(0xFFF5F5F5);
const Color siomaDark = Color(0xFF222222);
const double cardRadius = 16;

class AdminPage extends StatefulWidget {
  final FaceRecognitionService faceRecognitionService;

  const AdminPage({super.key, required this.faceRecognitionService});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late TabController _mainTabController;
  late TabController _historyTabController;

  List<RegisteredWorker> _workers = [];
  List<WorkLog> _logs = [];
  bool _isLoading = false;

  DateTime _selectedWeekStart =
      DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  DateTime get _selectedWeekEnd =>
      _selectedWeekStart.add(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _historyTabController = TabController(length: 2, vsync: this);
    _loadWorkers();
    _loadLogs();
  }

  // ======= SEMANAS =======
  void _changeWeek(int offset) {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.add(Duration(days: 7 * offset));
    });
  }

  List<WorkLog> _logsOfSelectedWeek(bool isEntry) => _logs
      .where(
        (log) =>
            log.isEntry == isEntry &&
            log.timestamp.isAfter(
                _selectedWeekStart.subtract(const Duration(seconds: 1))) &&
            log.timestamp.isBefore(
                _selectedWeekEnd.add(const Duration(days: 1))),
      )
      .toList();

  // ======= CARGA DE DATOS =======
  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    try {
      _workers = await _dbService.getAllWorkers();
    } catch (e) {
      _showSnackbar('Error al cargar trabajadores: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLogs() async {
    try {
      _logs = await _dbService.getAllWorkLogs();
      if (mounted) setState(() {});
    } catch (e) {
      _showSnackbar('Error al cargar historial: $e');
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: siomaRed.withOpacity(0.9),
    ));
  }

  RegisteredWorker _findWorkerById(String id) {
    return _workers.firstWhere(
      (w) => w.id == id,
      orElse: () => RegisteredWorker(
        name: 'Desconocido',
        id: id,
        faceEmbeddings: [],
        cedula: '',
        cargo: '',
      ),
    );
  }

  // ======= FUNCIONES =======
  Future<void> _deleteWorker(String id) async {
    try {
      await _dbService.deleteWorker(id);
      await _loadWorkers();
      _showSnackbar('Trabajador eliminado');
    } catch (e) {
      _showSnackbar('Error al eliminar trabajador: $e');
    }
  }

  Future<void> _exportLogsToCSV(bool isEntry) async {
    final logs = _logsOfSelectedWeek(isEntry);
    final buffer = StringBuffer('Nombre,Cédula,Cargo,Fecha,Hora,Tipo\n');
    for (final log in logs) {
      final worker = _findWorkerById(log.workerId);
      buffer.writeln(
          '${worker.name},${worker.cedula},${worker.cargo},${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year},'
          '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')},'
          '${log.isEntry ? 'Llegada' : 'Salida'}');
    }
    _showSnackbar('CSV generado (pendiente de guardar o compartir).');
  }

  // ======= CONFIGURACIÓN API =======
  Future<void> _showApiConfigDialog() async {
    final box = await Hive.openBox<AdminApiConfig>('admin_api_config');
    final config = box.get('config');
    final urlController = TextEditingController(text: config?.endpointUrl ?? '');
    final apiKeyController = TextEditingController(text: config?.apiKey ?? '');
    final headerController =
        TextEditingController(text: config?.customHeader ?? '');

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⚙️ Configurar API',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'URL del endpoint'),
              ),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(labelText: 'API Key'),
              ),
              TextField(
                controller: headerController,
                decoration:
                    const InputDecoration(labelText: 'Header personalizado'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: siomaRed, elevation: 0),
            onPressed: () async {
              final newConfig = AdminApiConfig(
                endpointUrl: urlController.text,
                apiKey: apiKeyController.text.isEmpty
                    ? null
                    : apiKeyController.text,
                customHeader: headerController.text.isEmpty
                    ? null
                    : headerController.text,
              );
              await box.put('config', newConfig);
              if (!mounted) return;
              Navigator.pop(context);
              _showSnackbar('Configuración guardada correctamente.');
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ======= SINCRONIZACIÓN =======
  Future<void> _syncWorkLogs() async {
    final apiBox = await Hive.openBox<AdminApiConfig>('admin_api_config');
    final config = apiBox.get('config');

    if (config == null || config.endpointUrl.isEmpty) {
      _showSnackbar('Configura primero la URL del endpoint.');
      return;
    }

    final unsynced = await _dbService.getUnsyncedLogs();
    if (unsynced.isEmpty) {
      _showSnackbar('No hay registros pendientes.');
      return;
    }

    final payload = unsynced
        .map((log) => {
              'workerId': log.workerId,
              'timestamp': log.timestamp.toIso8601String(),
              'isEntry': log.isEntry
            })
        .toList();

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (config.apiKey != null) headers['Authorization'] = config.apiKey!;
      if (config.customHeader != null)
        headers['X-Custom-Header'] = config.customHeader!;

      final response = await http.post(Uri.parse(config.endpointUrl),
          headers: headers, body: jsonEncode({'logs': payload}));

      if (response.statusCode == 200) {
        for (final log in unsynced) {
          await _dbService.markLogAsSynced(log);
        }
        _showSnackbar('✅ Sincronización completada.');
      } else {
        _showSnackbar('Error al sincronizar (${response.statusCode})');
      }
    } catch (e) {
      _showSnackbar('Error de red: $e');
    }
  }

  // ======= UI =======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: siomaGray,
      appBar: AppBar(
        backgroundColor: siomaWhite,
        elevation: 3,
        title: const Text('Panel de Administración',
            style: TextStyle(color: siomaDark, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: siomaDark),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Volver',
        ),
        bottom: TabBar(
          controller: _mainTabController,
          indicator: BoxDecoration(
              color: siomaRed, borderRadius: BorderRadius.circular(12)),
          labelColor: siomaWhite,
          unselectedLabelColor: siomaDark,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'Historial'),
            Tab(text: 'Usuarios'),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.sync, color: siomaDark),
              tooltip: 'Sincronizar',
              onPressed: _syncWorkLogs),
          IconButton(
              icon: const Icon(Icons.settings, color: siomaDark),
              tooltip: 'Configurar API',
              onPressed: _showApiConfigDialog),
        ],
      ),
      body: TabBarView(
        controller: _mainTabController,
        children: [_buildHistoryTab(), _buildUserTab()],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: siomaRed,
        tooltip: 'Registrar nuevo trabajador',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RegisterWorkerPage(faceRecognitionService: widget.faceRecognitionService),
            ),
          );
          _loadWorkers();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // ======= HISTORIAL =======
  Widget _buildHistoryTab() {
    return Column(
      children: [
        _buildWeekSelector(),
        const SizedBox(height: 8),
        _buildHistoryTabBar(),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _historyTabController,
            children: [_buildLogList(true), _buildLogList(false)],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _weekButton(Icons.arrow_back_ios_new, () => _changeWeek(-1)),
          Text(
            'Semana: ${_selectedWeekStart.day}/${_selectedWeekStart.month} - ${_selectedWeekEnd.day}/${_selectedWeekEnd.month}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: siomaDark),
          ),
          _weekButton(Icons.arrow_forward_ios, () => _changeWeek(1)),
        ],
      ),
    );
  }

  Widget _weekButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: siomaWhite,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)
          ],
        ),
        child: Icon(icon, size: 20, color: siomaDark),
      ),
    );
  }

  Widget _buildHistoryTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: siomaWhite,
          borderRadius: BorderRadius.circular(cardRadius),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: TabBar(
          controller: _historyTabController,
          indicator: BoxDecoration(
              color: siomaRed, borderRadius: BorderRadius.circular(12)),
          labelColor: siomaWhite,
          unselectedLabelColor: siomaDark,
          tabs: const [
            Tab(text: 'Llegadas'),
            Tab(text: 'Salidas'),
          ],
        ),
      ),
    );
  }

  Widget _buildLogList(bool isEntry) {
    final filtered = _logsOfSelectedWeek(isEntry);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: filtered.isEmpty
          ? const Center(child: Text('No hay registros esta semana.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (_, index) {
                final log = filtered[index];
                final worker = _findWorkerById(log.workerId);
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(cardRadius)),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isEntry ? Colors.green[100] : Colors.orange[100],
                      child: Icon(
                          isEntry ? Icons.login_rounded : Icons.logout_rounded,
                          color: isEntry ? Colors.green : Colors.orange),
                    ),
                    title: Text(worker.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year} - '
                        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}'),
                    trailing: Text(isEntry ? 'Llegada' : 'Salida',
                        style: TextStyle(
                            color: isEntry ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
    );
  }

  // ======= USUARIOS =======
  Widget _buildUserTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _workers.isEmpty
          ? const Center(child: Text('No hay trabajadores registrados.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _workers.length,
              itemBuilder: (_, index) {
                final worker = _workers[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(cardRadius)),
                  child: ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: siomaRed,
                        child: Icon(Icons.person, color: siomaWhite)),
                    title: Text(worker.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle:
                        Text('Cédula: ${worker.cedula}\nCargo: ${worker.cargo}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteWorker(worker.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
