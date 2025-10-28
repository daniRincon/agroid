import 'dart:math';
import 'package:viser/domain/services/face_recognition_service.dart';
import 'package:viser/domain/services/database_service.dart';
import 'package:viser/presentation/screens/admin_page.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:viser/config/theme/theme.dart';
import 'package:viser/domain/models/registered_worker.dart';
import 'package:viser/domain/models/work_log.dart';

class HomePage extends StatefulWidget {
  final FaceRecognitionService faceRecognitionService;

  const HomePage({super.key, required this.faceRecognitionService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String _feedbackMessage = '';
  bool _isSuccess = false;
  bool _isDetecting = false;
  bool _isEntryMode = true;

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  final DatabaseService _dbService = DatabaseService();

  int _recognitionAttempts = 0;
  static const int _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      _recognitionAttempts = 0;
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
        setState(() => _isCameraInitialized = true);
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

      final workers = await _dbService.getAllWorkers();
      RegisteredWorker? matchedWorker;
      double maxSimilarity = 0.0;

      for (final worker in workers) {
        double similarity = 0.0;
        for (final storedEmbedding in worker.faceEmbeddings) {
          final currentSimilarity =
              widget.faceRecognitionService.calculateSimilarity(embedding, storedEmbedding);
          similarity = max(similarity, currentSimilarity);
        }
        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          matchedWorker = worker;
        }
      }

      if (matchedWorker != null &&
          maxSimilarity >= FaceRecognitionService.similarityThreshold) {
        final currentTime = DateTime.now();
        final workLog = WorkLog(
          workerId: matchedWorker.id,
          timestamp: currentTime,
          isEntry: _isEntryMode,
        );
        await _dbService.addWorkLog(workLog);

        _showFeedback(
          _isEntryMode
              ? 'Hola ${matchedWorker.name}, tu entrada ha sido registrada con éxito.'
              : 'Gracias por tu jornada, ${matchedWorker.name}. Tu salida ha sido registrada.',
          isSuccess: true,
        );
        _resetDetection();
      } else {
        await _handleRecognitionFailure();
      }
    } catch (e) {
      await _handleRecognitionFailure(error: e.toString());
    }
  }

  Future<void> _handleRecognitionFailure({String? error}) async {
    _recognitionAttempts++;
    if (_recognitionAttempts >= _maxAttempts) {
      _showFeedback(
        error != null
            ? 'Error tras $_recognitionAttempts intentos: $error'
            : 'No se pudo reconocer tu rostro tras $_recognitionAttempts intentos. Contacta con el administrador.',
        isSuccess: false,
      );
      await Future.delayed(const Duration(seconds: 2));
      _resetDetection();
      return;
    }

    _showFeedback(
      error != null
          ? 'Error al procesar imagen: $error'
          : 'Rostro no reconocido. Por favor, intenta nuevamente.',
      isSuccess: false,
    );
    await Future.delayed(const Duration(seconds: 2));
    await _detectFaceAndProcess();
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
      if (mounted) setState(() => _feedbackMessage = '');
    });
  }

  void _showAdminPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String password = '';
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: const Text('Acceso Administrador',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            onChanged: (value) => password = value,
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppTheme.secondary),
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                if (password == '1234') {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        AdminPage(faceRecognitionService: widget.faceRecognitionService),
                  ));
                } else {
                  Navigator.of(context).pop();
                  _showFeedback('Contraseña incorrecta', isSuccess: false);
                }
              },
              child: const Text('Acceder'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: AppTheme.accent,
      appBar: AppBar(
        title: SizedBox(
          height: 80,
          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, size: 28),
            tooltip: 'Panel de Administración',
            onPressed: _showAdminPasswordDialog,
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async => !_isDetecting,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (!_isDetecting)
                Expanded(
                  child: Center(
                    child: Image.asset('assets/logoviser.png',
                        height: 300, fit: BoxFit.contain),
                  ),
                ),
              if (_isDetecting)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _isCameraInitialized && _cameraController != null
                          ? CameraPreview(_cameraController!)
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              if (!_isDetecting) _buildMainButtons(),
              if (_feedbackMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: _buildFeedbackWidget(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackWidget() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: _isSuccess ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (_isSuccess ? Colors.green : Colors.red).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: _isSuccess ? Colors.green[800] : Colors.red[800],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _feedbackMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isSuccess ? Colors.green[900] : Colors.red[900],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _startDetection(true),
            icon: const Icon(Icons.login, color: Colors.white),
            label: const Text('Registrar Entrada'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _startDetection(false),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Registrar Salida'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
          ),
        ),
      ],
    );
  }
}
