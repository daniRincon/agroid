import 'dart:math';
import 'package:viser/domain/services/face_recognition_service.dart';
import 'package:viser/domain/services/database_service.dart';
import 'package:viser/presentation/screens/admin_page.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:viser/domain/models/registered_worker.dart';
import 'package:viser/domain/models/work_log.dart';

class HomePage extends StatefulWidget {
  final FaceRecognitionService faceRecognitionService;

  const HomePage({super.key, required this.faceRecognitionService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // Estado de la UI
  String _feedbackMessage = '';
  bool _isSuccess = false;
  bool _isDetecting = false;
  bool _isEntryMode = true; // true: entrada, false: salida

  // Estado de la cámara
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  final DatabaseService _dbService = DatabaseService();

  int _recognitionAttempts = 0; // Contador de intentos
  static const int _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    print('🏠 Iniciando HomePage...');
    WidgetsBinding.instance.addObserver(this);
    // No inicializar cámara al inicio
    print('✅ HomePage inicializado');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _startDetection(bool isEntry) async {
    setState(() {
      _isDetecting = true;
      _isEntryMode = isEntry;
      _feedbackMessage = '';
      _recognitionAttempts = 0; // Reiniciar intentos al comenzar
    });
    await _initializeCamera();
    await Future.delayed(const Duration(milliseconds: 500));
    await _detectFaceAndProcess();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      _showFeedback("Error al iniciar la cámara: ${e.toString()}", isSuccess: false);
    }
  }

  Future<void> _detectFaceAndProcess() async {
    if (!_isCameraInitialized || _cameraController == null) return;
    try {
      final image = await _cameraController!.takePicture();
      final embedding = await widget.faceRecognitionService.processImage(image);
      
      // Buscar coincidencia en la base de datos
      final workers = await _dbService.getAllWorkers();
      RegisteredWorker? matchedWorker;
      double maxSimilarity = 0.0;
      for (final worker in workers) {
        double similarity = 0.0;
        for (final storedEmbedding in worker.faceEmbeddings) {
          final currentSimilarity = widget.faceRecognitionService.calculateSimilarity(embedding, storedEmbedding);
          similarity = max(similarity, currentSimilarity);
        }
        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          matchedWorker = worker;
        }
      }
      if (matchedWorker != null && maxSimilarity >= FaceRecognitionService.similarityThreshold) {
        final currentTime = DateTime.now();
        final workLog = WorkLog(
          workerId: matchedWorker.id,
          timestamp: currentTime,
          isEntry: _isEntryMode,
        );
        await _dbService.addWorkLog(workLog);
        _showFeedback(
          _isEntryMode
            ? '¡Bienvenido, ${matchedWorker.name}! Tu ingreso ha sido registrado.'
            : '¡Hasta pronto, ${matchedWorker.name}! Tu salida ha sido registrada.',
          isSuccess: true
        );
        _resetDetection();
      } else {
        _recognitionAttempts++;
        if (_recognitionAttempts >= _maxAttempts) {
          _showFeedback('No se encontró coincidencia tras $_recognitionAttempts intentos', isSuccess: false);
          await Future.delayed(const Duration(seconds: 2));
          _resetDetection();
          return;
        }
        _showFeedback('No se encontró coincidencia', isSuccess: false);
        await Future.delayed(const Duration(seconds: 2));
        await _detectFaceAndProcess();
      }
    } catch (e) {
      _recognitionAttempts++;
      if (_recognitionAttempts >= _maxAttempts) {
        _showFeedback('Error tras $_recognitionAttempts intentos: ${e.toString()}', isSuccess: false);
        await Future.delayed(const Duration(seconds: 2));
        _resetDetection();
        return;
      }
      _showFeedback('Error al procesar imagen: ${e.toString()}', isSuccess: false);
      await Future.delayed(const Duration(seconds: 2));
      await _detectFaceAndProcess();
    }
  }

  void _resetDetection() {
    setState(() {
      _isDetecting = false;
      _isCameraInitialized = false;
      _cameraController?.dispose();
      _cameraController = null;
      _recognitionAttempts = 0;
    });
  }

  void _showFeedback(String message, {bool isSuccess = false}) {
    setState(() {
      _feedbackMessage = message;
      _isSuccess = isSuccess;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _feedbackMessage = '';
        });
      }
    });
  }

  void _showAdminPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String password = '';
        return AlertDialog(
          title: const Text('Acceso Administrador'),
          content: TextField(
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
            ),
            onChanged: (value) {
              password = value;
            },
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
              ),
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Acceder'),
              onPressed: () async {
                if (password == '1234') {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AdminPage(
                        faceRecognitionService: widget.faceRecognitionService,
                      ),
                    ),
                  );
                } else {
                  Navigator.of(context).pop();
                  _showFeedback('Contraseña incorrecta', isSuccess: false);
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final cameraHeight = media.size.height * 0.45;
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 90,
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Panel de Administración',
            onPressed: _showAdminPasswordDialog,
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async => !_isDetecting,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (!_isDetecting) ...[
                    SizedBox(height: media.size.height * 0.06),
                    Center(
                      child: Image.asset(
                        'assets/logoviser.png',
                        height: 400,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: media.size.height * 0.06),
                  ],
                  if (_isDetecting)
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: cameraHeight,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                border: Border.all(
                                  color: Theme.of(context).primaryColor.withAlpha(128),
                                  width: 2,
                                ),
                              ),
                              child: _isCameraInitialized && _cameraController != null
                                  ? CameraPreview(_cameraController!)
                                  : const Center(child: CircularProgressIndicator()),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    _buildMainButtons(),
                  SizedBox(height: media.size.height * 0.03),
                  if (_feedbackMessage.isNotEmpty)
                    _buildFeedbackWidget(media),
                  const Spacer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeedbackWidget(MediaQueryData media) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: media.size.width * 0.95,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _isSuccess ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isSuccess ? Icons.check_circle : Icons.error,
            color: _isSuccess ? Colors.green[800] : Colors.red[800],
            size: 28,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _feedbackMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isSuccess ? Colors.green[800] : Colors.red[800],
                fontWeight: FontWeight.bold,
                fontSize: media.size.width < 400 ? 14 : 18,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _startDetection(true),
            child: const Text('Registrar Entrada'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _startDetection(false),
            child: const Text('Registrar Salida'),
          ),
        ),
      ],
    );
  }
}