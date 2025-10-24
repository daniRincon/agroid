import 'dart:math';
import 'package:agroid/domain/services/face_recognition_service.dart';
import 'package:agroid/domain/services/database_service.dart';
import 'package:agroid/presentation/screens/admin_page.dart';
import 'package:agroid/presentation/widgets/sioma_logo.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:agroid/domain/models/registered_worker.dart';
import 'package:agroid/domain/models/work_log.dart';

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

  // Estado de la cámara
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    widget.faceRecognitionService.loadModel(); // Inicializa el modelo TFLite
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
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

  Future<void> _showAdminPasswordDialog() async {
    final passwordController = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Acceso de Administrador'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Por favor, introduce la contraseña.'),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Acceder'),
              onPressed: () {
                // TODO: Usar un método de autenticación más seguro
                if (passwordController.text == '1234') {
                  Navigator.of(context).pop(); // Cierra el diálogo
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AdminPage(
                        faceRecognitionService: widget.faceRecognitionService,
                      ),
                    ),
                  ).then((_) => _initializeCamera()); // Re-inicializa la cámara al volver
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _processFaceRecognition() async {
    if (!_isCameraInitialized || _cameraController == null) {
      _showFeedback('La cámara no está lista', isSuccess: false);
      return;
    }

    try {
      // Tomar la foto
      final XFile imageFile = await _cameraController!.takePicture();
      // Procesar la imagen para reconocimiento facial
      var embedding = await widget.faceRecognitionService.processImage(imageFile);
      embedding = _normalize(embedding);

      // Buscar coincidencia en la base de datos usando distancia coseno
      final workers = _dbService.getAllWorkers();
      RegisteredWorker? matchedWorker;
      double maxSimilarity = -1.0;
      for (final worker in workers) {
        final workerEmbedding = _normalize(worker.embedding);
        final similarity = _cosineSimilarity(workerEmbedding, embedding);
        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          matchedWorker = worker;
        }
      }
      // Umbral de similitud (ajustado para coseno, más estricto)
      const threshold = 0.78; // 1.0 es idéntico, 0.0 es ortogonal
      if (matchedWorker != null && maxSimilarity > threshold) {
        // Registrar entrada/salida
        final log = WorkLog(
          workerName: matchedWorker.name,
          timestamp: DateTime.now(),
          logType: "entrada", // Puedes cambiar a "salida" según el botón
        );
        await _dbService.saveWorkLog(log);
        _showFeedback('¡Bienvenido, ${matchedWorker.name}!\nSimilitud: ${maxSimilarity.toStringAsFixed(3)}', isSuccess: true);
      } else {
        _showFeedback('No se encontró coincidencia.\nSimilitud máxima: ${maxSimilarity.toStringAsFixed(3)}', isSuccess: false);
      }
    } catch (e) {
      _showFeedback('Error al procesar la imagen: \n${e.toString()}', isSuccess: false);
    }
  }

  List<double> _normalize(List<double> v) {
    final norm = sqrt(v.fold(0.0, (sum, x) => sum + x * x));
    return v.map((x) => x / (norm == 0 ? 1 : norm)).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (sqrt(normA) * sqrt(normB));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgroID'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Panel de Administración',
            onPressed: _showAdminPasswordDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SiomaLogo(size: 120),
            const SizedBox(height: 24),
            Expanded(
              child: _buildCameraPreview(),
            ),
            const SizedBox(height: 24),
            if (_feedbackMessage.isNotEmpty) _buildFeedbackWidget(),
            const Spacer(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final theme = Theme.of(context);
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(
              color: theme.primaryColor.withAlpha(128),
              width: 2,
            ),
          ),
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildFeedbackWidget() {
    return Container(
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
          ),
          const SizedBox(width: 8),
          Text(
            _feedbackMessage,
            style: TextStyle(
              color: _isSuccess ? Colors.green[800] : Colors.red[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _processFaceRecognition,
            child: const Text('Registrar Entrada'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _processFaceRecognition,
            child: const Text('Registrar Salida'),
          ),
        ),
      ],
    );
  }
}