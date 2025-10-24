import 'package:agroid/domain/models/registered_worker.dart';
import 'package:agroid/domain/services/database_service.dart';
import 'package:agroid/domain/services/face_recognition_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class RegisterWorkerPage extends StatefulWidget {
  final FaceRecognitionService faceRecognitionService;

  const RegisterWorkerPage({super.key, required this.faceRecognitionService});

  @override
  State<RegisterWorkerPage> createState() => _RegisterWorkerPageState();
}

class _RegisterWorkerPageState extends State<RegisterWorkerPage> {
  // Servicios
  late final FaceRecognitionService _faceRecognitionService = widget.faceRecognitionService;
  final DatabaseService _dbService = DatabaseService();

  // Controles de UI
  final _nameController = TextEditingController();
  bool _isSaving = false;

  // Cámara
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // Multi-captura
  int _captureStep = 0;
  final int _totalSteps = 5;
  final List<String> _instructions = [
    'Mira de frente a la cámara',
    'Gira tu rostro ligeramente a la izquierda',
    'Gira tu rostro ligeramente a la derecha',
    'Inclina tu rostro hacia arriba',
    'Inclina tu rostro hacia abajo',
  ];
  final List<List<double>> _embeddings = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _nameController.dispose();
    super.dispose();
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
        ResolutionPreset.high, // Usar alta resolución para la captura
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      // Manejar error
    }
  }

  Future<void> _onMultiCaptureAndSave() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, introduce un nombre.')),
      );
      return;
    }
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    setState(() {
      _isSaving = true;
      _captureStep = 0;
      _embeddings.clear();
    });
    await _captureNextStep();
  }

  Future<void> _captureNextStep() async {
    if (_captureStep >= _totalSteps) {
      // Promediar embeddings
      final avgEmbedding = List<double>.filled(_embeddings[0].length, 0.0);
      for (var emb in _embeddings) {
        for (int i = 0; i < emb.length; i++) {
          avgEmbedding[i] += emb[i];
        }
      }
      for (int i = 0; i < avgEmbedding.length; i++) {
        avgEmbedding[i] /= _totalSteps;
      }
      // Guardar trabajador
      final newWorker = RegisteredWorker(
        name: _nameController.text,
        embedding: avgEmbedding,
      );
      await _dbService.saveWorker(newWorker);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡${_nameController.text} registrado con éxito!')),
        );
        Navigator.of(context).pop();
      }
      setState(() {
        _isSaving = false;
      });
      return;
    }
    // Mostrar instrucción y esperar confirmación del usuario
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Captura Facial'),
        content: Text(_instructions[_captureStep]),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Capturar foto y procesar embedding
              final image = await _cameraController!.takePicture();
              final embedding = await _faceRecognitionService.processImage(image);
              _embeddings.add(embedding);
              setState(() {
                _captureStep++;
              });
              await _captureNextStep();
            },
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Trabajador'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 5,
                child: _isCameraInitialized
                    ? CameraPreview(_cameraController!)
                    : const Center(child: CircularProgressIndicator()),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Trabajador',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Capturar y Guardar'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: _isSaving ? null : _onMultiCaptureAndSave,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withAlpha(128), // Corregido
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Guardando...', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}