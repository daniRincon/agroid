import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:viser/domain/models/admin_api_config.dart';
import 'package:viser/domain/models/registered_worker.dart';
import 'package:viser/domain/models/work_log.dart';
import 'package:viser/domain/services/database_service.dart';
import 'package:viser/domain/services/face_recognition_service.dart';
import 'package:viser/presentation/screens/register_worker_page.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

// Colores Sioma
const Color siomaRed = Color(0xFFC8102E);
const Color siomaWhite = Color(0xFFFFFFFF);
const Color siomaGray = Color(0xFFF5F5F5);
const Color siomaDark = Color(0xFF222222);

class AdminPage extends StatefulWidget {
  final FaceRecognitionService faceRecognitionService;

  const AdminPage({super.key, required this.faceRecognitionService});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  List<RegisteredWorker> _workers = [];
  List<WorkLog> _logs = [];
  bool _isLoading = false;

  late TabController _mainTabController;
  late TabController _historyTabController;

  // --- NUEVO: Filtro de semana y exportación ---
  DateTime _selectedWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  DateTime get _selectedWeekEnd => _selectedWeekStart.add(const Duration(days: 6));

  void _changeWeek(int offset) {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.add(Duration(days: 7 * offset));
    });
  }

  List<WorkLog> _logsOfSelectedWeek(bool isEntry) {
    return _logs.where((log) =>
      log.isEntry == isEntry &&
      log.timestamp.isAfter(_selectedWeekStart.subtract(const Duration(seconds: 1))) &&
      log.timestamp.isBefore(_selectedWeekEnd.add(const Duration(days: 1)))
    ).toList();
  }

  Future<void> _exportLogsToCSV(bool isEntry) async {
    final logs = _logsOfSelectedWeek(isEntry);
    final buffer = StringBuffer();
    buffer.writeln('Nombre,Cédula,Cargo,Fecha,Hora,Tipo');
    for (final log in logs) {
      final worker = _workers.firstWhere(
        (w) => w.id == log.workerId,
        orElse: () => RegisteredWorker(name: 'Desconocido', id: log.workerId, faceEmbeddings: [], cedula: '', cargo: ''),
      );
      buffer.writeln(
        '${worker.name},${worker.cedula},${worker.cargo},'
        '${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year},'
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')},'
        '${log.isEntry ? 'Llegada' : 'Salida'}'
      );
    }
    // Aquí puedes guardar el archivo usando path_provider y compartirlo
    // Por simplicidad, solo mostramos un mensaje
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV generado. Implementa guardado/compartir según plataforma.')),
    );
  }

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _historyTabController = TabController(length: 2, vsync: this);
    _loadWorkers();
    _loadLogs();
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    try {
      final workers = await _dbService.getAllWorkers();
      if (mounted) {
        setState(() {
          _workers = workers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar trabajadores: $e')),
        );
      }
    }
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await _dbService.getAllWorkLogs();
      if (mounted) {
        setState(() {
          _logs = logs;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar historial: $e')),
        );
      }
    }
  }

  Future<void> _deleteWorker(String id) async {
    try {
      await _dbService.deleteWorker(id);
      if (!mounted) return;
      
      await _loadWorkers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trabajador eliminado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar trabajador: $e')),
      );
    }
  }

  Future<void> _showApiConfigDialog() async {
    final box = await Hive.openBox<AdminApiConfig>('admin_api_config');
    final config = box.get('config');
    final urlController = TextEditingController(text: config?.endpointUrl ?? '');
    final apiKeyController = TextEditingController(text: config?.apiKey ?? '');
    final headerController = TextEditingController(text: config?.customHeader ?? '');

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar API'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'URL del endpoint'),
              ),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(labelText: 'API Key (opcional)'),
              ),
              TextField(
                controller: headerController,
                decoration: const InputDecoration(labelText: 'Header personalizado (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newConfig = AdminApiConfig(
                endpointUrl: urlController.text,
                apiKey: apiKeyController.text.isEmpty ? null : apiKeyController.text,
                customHeader: headerController.text.isEmpty ? null : headerController.text,
              );
              await box.put('config', newConfig);

              if (!mounted) return;
              
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuración guardada')),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncWorkLogs() async {
    final apiBox = await Hive.openBox<AdminApiConfig>('admin_api_config');
    final config = apiBox.get('config');

    if (!mounted) return;

    if (config == null || config.endpointUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura primero la URL del endpoint.')),
      );
      return;
    }

    final unsynced = await _dbService.getUnsyncedLogs();
    
    if (!mounted) return;

    if (unsynced.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros pendientes de sincronizar.')),
      );
      return;
    }

    // Copy-on-Write: copia de los registros
    final logsToSync = List<WorkLog>.from(unsynced);
    final payload = logsToSync.map((log) => {
      'workerId': log.workerId,
      'timestamp': log.timestamp.toIso8601String(),
      'isEntry': log.isEntry,
    }).toList();

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (config.apiKey != null) headers['Authorization'] = config.apiKey!;
      if (config.customHeader != null) headers['X-Custom-Header'] = config.customHeader!;

      final response = await http.post(
        Uri.parse(config.endpointUrl),
        headers: headers,
        body: jsonEncode({'logs': payload}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Marcar como sincronizados
        for (final log in logsToSync) {
          await _dbService.markLogAsSynced(log);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Sincronización exitosa!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Administración'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              color: siomaWhite,
              child: TabBar(
                controller: _mainTabController,
                indicator: BoxDecoration(
                  color: siomaRed,
                  borderRadius: BorderRadius.circular(16),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: siomaWhite,
                unselectedLabelColor: siomaDark,
                labelStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 16),
                unselectedLabelStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 16),
                tabs: [
                  Container(
                    height: 40,
                    alignment: Alignment.center,
                    child: const Text('Historial'),
                  ),
                  Container(
                    height: 40,
                    alignment: Alignment.center,
                    child: const Text('Gestión de Usuarios'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sincronizar registros',
              onPressed: _syncWorkLogs,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configurar API',
              onPressed: _showApiConfigDialog,
            ),
          ],
        ),
        body: TabBarView(
          controller: _mainTabController,
          children: [
            _buildHistoryTab(),
            _buildUserTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => RegisterWorkerPage(
                  faceRecognitionService: widget.faceRecognitionService,
                ),
              ),
            );
            _loadWorkers();
          },
          tooltip: 'Registrar Nuevo Trabajador',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Container(
      color: siomaGray,
      child: Column(
        children: [
          Container(
            color: siomaWhite,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _changeWeek(-1),
                ),
                Text(
                  'Semana: ${_selectedWeekStart.day}/${_selectedWeekStart.month} - ${_selectedWeekEnd.day}/${_selectedWeekEnd.month}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _changeWeek(1),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: siomaWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: TabBar(
              controller: _historyTabController,
              indicator: BoxDecoration(
                color: siomaRed,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: siomaWhite,
              unselectedLabelColor: siomaDark,
              labelStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 15),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 15),
              tabs: [
                Container(
                  height: 36,
                  alignment: Alignment.center,
                  child: const Text('Llegadas'),
                ),
                Container(
                  height: 36,
                  alignment: Alignment.center,
                  child: const Text('Salidas'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _historyTabController,
              children: [
                _buildLogList(true),
                _buildLogList(false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(bool isEntry) {
    final filtered = _logsOfSelectedWeek(isEntry);
    if (filtered.isEmpty) {
      return const Center(child: Text('No hay registros esta semana.'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Exportar a Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: siomaRed,
              foregroundColor: siomaWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _exportLogsToCSV(isEntry),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final log = filtered[index];
              final worker = _workers.firstWhere(
                (w) => w.id == log.workerId,
                orElse: () => RegisteredWorker(name: 'Desconocido', id: log.workerId, faceEmbeddings: [], cedula: '', cargo: ''),
              );
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(worker.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Fecha: ${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year}\nHora: ${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: Text(isEntry ? 'Llegada' : 'Salida', style: TextStyle(color: isEntry ? Colors.green : Colors.red)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserTab() {
    return Container(
      color: siomaGray,
      child: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _workers.isEmpty
          ? const Center(child: Text('No hay trabajadores registrados.'))
          : ListView.builder(
              itemCount: _workers.length,
              itemBuilder: (context, index) {
                final worker = _workers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(worker.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Cédula: ${worker.cedula}\nCargo: ${worker.cargo}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditWorkerDialog(worker),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteDialog(worker),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showEditWorkerDialog(RegisteredWorker worker) async {
    final nameController = TextEditingController(text: worker.name);
    final cedulaController = TextEditingController(text: worker.cedula);
    final cargoController = TextEditingController(text: worker.cargo);
    bool isEnabled = worker.enabled;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: const Text('Editar trabajador'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
              ),
              TextField(
                controller: cedulaController,
                decoration: const InputDecoration(labelText: 'Cédula'),
              ),
              TextField(
                controller: cargoController,
                decoration: const InputDecoration(labelText: 'Cargo'),
              ),
              SwitchListTile(
                title: const Text('Habilitado'),
                value: isEnabled,
                onChanged: (val) {
                  setDialogState(() {
                    isEnabled = val;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              worker.name = nameController.text;
              worker.cedula = cedulaController.text;
              worker.cargo = cargoController.text;
              worker.enabled = isEnabled;
              await _dbService.updateWorker(worker);
              Navigator.of(context).pop();
              _loadWorkers();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Trabajador actualizado')),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(RegisteredWorker worker) async {
    if (!mounted) return;
    
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar a ${worker.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      await _deleteWorker(worker.id);
    }
  }
}