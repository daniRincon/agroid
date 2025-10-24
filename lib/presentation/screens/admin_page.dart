import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:agroid/domain/models/admin_api_config.dart';
import 'package:agroid/domain/models/registered_worker.dart';
import 'package:agroid/domain/models/work_log.dart';
import 'package:agroid/domain/services/database_service.dart';
import 'package:agroid/domain/services/face_recognition_service.dart';
import 'package:agroid/presentation/screens/register_worker_page.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AdminPage extends StatefulWidget {
  final FaceRecognitionService faceRecognitionService;

  const AdminPage({super.key, required this.faceRecognitionService});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final DatabaseService _dbService = DatabaseService();
  late List<RegisteredWorker> _workers;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  void _loadWorkers() {
    setState(() {
      _workers = _dbService.getAllWorkers();
    });
  }

  Future<void> _deleteWorker(String name) async {
    await _dbService.deleteWorker(name);
    _loadWorkers(); // Recargar la lista
  }

  Future<void> _showApiConfigDialog() async {
    final box = await Hive.openBox<AdminApiConfig>('admin_api_config');
    final config = box.get('config');
    final urlController = TextEditingController(text: config?.endpointUrl ?? '');
    final apiKeyController = TextEditingController(text: config?.apiKey ?? '');
    final headerController = TextEditingController(text: config?.customHeader ?? '');
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
    if (config == null || config.endpointUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura primero la URL del endpoint.')),
      );
      return;
    }
    final unsynced = _dbService.getUnsyncedLogs();
    if (unsynced.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros pendientes de sincronizar.')),
      );
      return;
    }
    // Copy-on-Write: copia de los registros
    final logsToSync = List<WorkLog>.from(unsynced);
    final payload = logsToSync.map((log) => {
      'workerName': log.workerName,
      'timestamp': log.timestamp.toIso8601String(),
      'logType': log.logType,
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
      if (response.statusCode == 200) {
        // Marcar como sincronizados
        for (final log in logsToSync) {
          log.isSynced = true;
          await log.save();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
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
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navegar a la página de registro y esperar a que se complete.
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RegisterWorkerPage(
                faceRecognitionService: widget.faceRecognitionService,
              ),
            ),
          );
          // Al regresar, recargar la lista de trabajadores.
          _loadWorkers();
        },
        tooltip: 'Registrar Nuevo Trabajador',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_workers.isEmpty) {
      return const Center(
        child: Text(
          'No hay trabajadores registrados.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _workers.length,
      itemBuilder: (context, index) {
        final worker = _workers[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(worker.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Eliminar Trabajador',
              onPressed: () => _showDeleteConfirmation(worker.name),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(String workerName) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Estás seguro de que quieres eliminar a $workerName? Esta acción no se puede deshacer.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
              onPressed: () {
                _deleteWorker(workerName);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}