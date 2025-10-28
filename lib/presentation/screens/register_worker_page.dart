import 'dart:io';
import 'package:viser/domain/models/registered_worker.dart';
import 'package:viser/domain/services/database_service.dart';
import 'package:viser/domain/services/face_recognition_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// 🎨 Paleta corporativa VISER
const Color siomaRed = Color(0xFFC8102E);
const Color siomaWhite = Color(0xFFFFFFFF);
const Color siomaGray = Color(0xFFF5F5F5);
const Color siomaDark = Color(0xFF222222);

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

  // Controladores de texto
  final _nameController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _cargoController = TextEditingController();

  // Estado
  bool _isSaving = false;

  // Cámara
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // Capturas
  int _captureStep = 0;
  final int _totalSteps = 5;
  final List<String> _instructions = [
    'Mira de frente a la cámara',
    'Gira ligeramente a la izquierda',
    'Gira ligeramente a la derecha',
    'Inclina tu rostro hacia arriba',
    'Inclina tu rostro hacia abajo',
  ];
  final List<List<double>> _embeddings = [];

  // Imágenes manuales
  final picker = ImagePicker();
  final List<File?> _selectedImages = List.filled(5, null);
  final List<String> _angles = ['Frente', 'Izquierda', 'Derecha', 'Arriba', 'Abajo'];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceRecognitionService.loadModel();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _nameController.dispose();
    _cedulaController.dispose();
    _cargoController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
      await _cameraController!.initialize();

      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (_) {}
  }

  // 📷 Modal de cámara (corregido y mejorado)
  Future<void> _showCameraModal() async {
    if (_nameController.text.isEmpty || _cedulaController.text.isEmpty || _cargoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos antes de capturar.')),
      );
      return;
    }

    _captureStep = 0;
    _embeddings.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: siomaWhite,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            builder: (_, controller) => SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Captura facial',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: siomaRed,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Paso ${_captureStep + 1} de $_totalSteps',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Montserrat')),
                  const SizedBox(height: 16),

                  // 🔹 Cámara más pequeña, centrada y con animación suave
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      key: ValueKey(_captureStep),
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: _isCameraInitialized
                          ? CameraPreview(_cameraController!)
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),

                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _instructions[_captureStep],
                      key: ValueKey(_instructions[_captureStep]),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_captureStep < _totalSteps - 1 ? 'Capturar' : 'Finalizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: siomaRed,
                      foregroundColor: siomaWhite,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final image = await _cameraController!.takePicture();
                      try {
                        final embedding = await _faceRecognitionService.processImage(image);
                        _embeddings.add(embedding);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Captura exitosa.'),
                            backgroundColor: Colors.green[100],
                            behavior: SnackBarBehavior.floating,
                          ),
                        );

                        if (_captureStep < _totalSteps - 1) {
                          setModalState(() => _captureStep++);
                        } else {
                          Navigator.pop(context);
                        }
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No se detectó rostro. Intenta nuevamente.')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // 🖼️ Modal de selección manual
  void _showManualModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: siomaWhite,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Registro manual con imágenes',
                style: TextStyle(
                  color: siomaRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(5, (i) {
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedImages[i] != null ? siomaRed : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: _selectedImages[i] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_selectedImages[i]!, fit: BoxFit.cover),
                            )
                          : const Icon(Icons.image, color: Colors.grey),
                    ),
                    title: Text(
                      _angles[i],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Subir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: siomaRed,
                        foregroundColor: siomaWhite,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setState(() => _selectedImages[i] = File(picked.path));
                        }
                      },
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Listo, continuar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: siomaDark,
                  foregroundColor: siomaWhite,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 💾 Guardar registro
  Future<void> _processAllImages() async {
    if (_nameController.text.isEmpty || _cedulaController.text.isEmpty || _cargoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    if (_embeddings.isEmpty && _selectedImages.every((img) => img == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay capturas ni imágenes cargadas')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final embeddings = <List<double>>[];

      embeddings.addAll(_embeddings);
      for (final file in _selectedImages) {
        if (file != null) embeddings.add(await _faceRecognitionService.processImageFromFile(file));
      }

      final worker = RegisteredWorker(
        name: _nameController.text,
        cedula: _cedulaController.text,
        cargo: _cargoController.text,
        faceEmbeddings: embeddings,
        id: '',
      );

      await _dbService.addWorker(worker);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_nameController.text} registrado con éxito'),
            backgroundColor: Colors.green[100],
            behavior: SnackBarBehavior.floating,
          ),
        );
        _nameController.clear();
        _cedulaController.clear();
        _cargoController.clear();
        _selectedImages.fillRange(0, 5, null);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // 🧱 UI principal
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: siomaWhite,
      appBar: AppBar(
        backgroundColor: siomaRed,
        centerTitle: true,
        title: const Text(
          'Registro de Trabajador',
          style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Registro Facial VISER',
                  style: TextStyle(
                    fontSize: 22,
                    color: siomaRed,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: _inputDecoration('Nombre completo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cedulaController,
                  decoration: _inputDecoration('Cédula'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cargoController,
                  decoration: _inputDecoration('Cargo'),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _customButton(Icons.camera_alt, 'Usar cámara', siomaRed, _showCameraModal),
                    _customButton(Icons.image, 'Cargar imágenes', siomaDark, _showManualModal),
                  ],
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar registro'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: siomaRed,
                    foregroundColor: siomaWhite,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _processAllImages,
                ),
              ],
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: siomaWhite),
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

  // 🧩 Helpers visuales
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: siomaGray,
      labelStyle: const TextStyle(color: siomaRed, fontFamily: 'Montserrat'),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _customButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: siomaWhite,
        minimumSize: const Size(160, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
    );
  }
}
