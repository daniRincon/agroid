import 'dart:io';
import 'package:viser/domain/models/registered_worker.dart';
import 'package:viser/domain/services/database_service.dart';
import 'package:viser/domain/services/face_recognition_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Colores Sioma
const Color siomaRed = Color(0xFFC8102E); // Rojo principal Sioma
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

  // Controles de UI
  final _nameController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _cargoController = TextEditingController();
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

  // Para registro manual
  final List<File?> _selectedImages = List.filled(5, null);
  final List<String> _angles = ['Frente', 'Izquierda', 'Derecha', 'Arriba', 'Abajo'];
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceRecognitionService.loadModel().then((_) {
      setState(() {
        // Modelo cargado
      });
    });
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

  void _activateCamera() {
    _showCameraModal();
  }

  void _showManualModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: siomaWhite,
      builder: (context) {
        final media = MediaQuery.of(context);
        final cardSize = media.size.width < 400 ? 48.0 : 64.0;
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text('Registro manual con imágenes', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat', fontSize: 18)),
                  const SizedBox(height: 12),
                  ...List.generate(5, (i) => Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Row(
                        children: [
                          Container(
                            width: cardSize,
                            height: cardSize,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedImages[i] != null ? siomaRed : Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _selectedImages[i] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedImages[i]!,
                                      width: cardSize,
                                      height: cardSize,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: cardSize,
                                        height: cardSize,
                                        color: Colors.red[100],
                                        child: const Icon(Icons.error, color: Colors.red, size: 28),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Icon(Icons.image, color: Colors.grey, size: 28),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_angles[i], style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.upload_file, size: 18),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: siomaRed,
                                    foregroundColor: siomaWhite,
                                    minimumSize: const Size(80, 32),
                                    textStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: _isSaving ? null : () async {
                                    await _pickImage(i);
                                    setState(() {}); // Forzar actualización visual
                                  },
                                  label: const Text('Seleccionar'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: _isSaving ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white) : const Icon(Icons.image),
                    label: const Text('Seleccionar Imágenes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: siomaRed,
                      foregroundColor: siomaWhite,
                      minimumSize: Size(media.size.width * 0.7, 48),
                      textStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving ? null : () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Imágenes seleccionadas. Presiona "Guardar" para registrar.')),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCameraModal() async {
    if (_nameController.text.isEmpty || _cedulaController.text.isEmpty || _cargoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos antes de capturar.')),
      );
      return;
    }

    setState(() {
      _captureStep = 0;
      _embeddings.clear();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: siomaWhite,
      builder: (context) {
        final media = MediaQuery.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.95,
              minChildSize: 0.7,
              maxChildSize: 1.0,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text('Captura facial', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 20, color: siomaRed)),
                      const SizedBox(height: 16),
                      Text('Paso ${_captureStep + 1} de $_totalSteps', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, fontSize: 16, color: siomaDark)),
                      const SizedBox(height: 8),
                      AspectRatio(
                        aspectRatio: 9/16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _isCameraInitialized && _cameraController != null
                            ? CameraPreview(_cameraController!)
                            : const Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(_instructions[_captureStep], style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: Text(_captureStep < _totalSteps - 1 ? 'Capturar' : 'Terminar Capturas'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: siomaRed,
                          foregroundColor: siomaWhite,
                          minimumSize: Size(media.size.width * 0.7, 48),
                          textStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final image = await _cameraController!.takePicture();
                          try {
                            final embedding = await _faceRecognitionService.processImage(image, skipFrameCheck: true);
                            _embeddings.add(embedding);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green, size: 22),
                                      const SizedBox(width: 8),
                                      Text('Captura exitosa', style: const TextStyle(fontFamily: 'Montserrat')),
                                    ],
                                  ),
                                  backgroundColor: Colors.green[100],
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.error, color: Colors.red, size: 22),
                                      const SizedBox(width: 8),
                                      Text('No se pudo detectar un rostro claro', style: const TextStyle(fontFamily: 'Montserrat')),
                                    ],
                                  ),
                                  backgroundColor: Colors.red[100],
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                            return;
                          }
                          
                          setModalState(() {
                            _captureStep++;
                          });
                          
                          if (_captureStep >= _totalSteps) {
                            // Solo cerrar el modal, no guardar aún
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.blue, size: 22),
                                      const SizedBox(width: 8),
                                      Text('Capturas completadas. Presiona "Guardar" para registrar.', style: const TextStyle(fontFamily: 'Montserrat')),
                                    ],
                                  ),
                                  backgroundColor: Colors.blue[100],
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                              Navigator.of(context).pop();
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pickImage(int index) async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImages[index] = File(pickedFile.path);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 22),
                const SizedBox(width: 8),
                Text('Imagen cargada correctamente', style: const TextStyle(fontFamily: 'Montserrat')),
              ],
            ),
            backgroundColor: Colors.green[100],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }


  Future<void> _processAllImages() async {
    if (_nameController.text.isEmpty || _cedulaController.text.isEmpty || _cargoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
      return;
    }

    // Verificar si hay capturas de cámara o imágenes seleccionadas
    final hasEmbeddings = _embeddings.isNotEmpty;
    final hasSelectedImages = _selectedImages.where((img) => img != null).isNotEmpty;

    if (!hasEmbeddings && !hasSelectedImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, captura fotos con la cámara o selecciona imágenes.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      List<List<double>> allEmbeddings = [];
      
      // Agregar embeddings de capturas de cámara si existen
      if (hasEmbeddings) {
        allEmbeddings.addAll(_embeddings);
      }
      
      // Procesar imágenes seleccionadas si existen
      if (hasSelectedImages) {
        for (var file in _selectedImages) {
          if (file != null) {
            try {
              final emb = await _faceRecognitionService.processImageFromFile(file);
              allEmbeddings.add(emb);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al procesar imagen: ${e.toString()}')),
                );
              }
              continue;
            }
          }
        }
      }

      if (allEmbeddings.isEmpty) {
        throw Exception('No se pudo procesar ninguna imagen correctamente');
      }

      // Guardar trabajador
      final newWorker = RegisteredWorker(
        name: _nameController.text,
        faceEmbeddings: allEmbeddings,
        cedula: _cedulaController.text,
        cargo: _cargoController.text,
        id: '',
      );

      await _dbService.addWorker(newWorker);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡${_nameController.text} registrado con éxito!')),
        );
        
        // Limpiar formulario y datos
        _nameController.clear();
        _cedulaController.clear();
        _cargoController.clear();
        _embeddings.clear();
        for (int i = 0; i < _selectedImages.length; i++) {
          _selectedImages[i] = null;
        }
        _captureStep = 0;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar trabajador: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: siomaWhite,
      appBar: AppBar(
        backgroundColor: siomaRed,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/hoja.png',
              height: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Registrar Trabajador',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Logo de viser eliminado
                const SizedBox(height: 8),
                Text(
                  'Registro Facial VISER',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: siomaRed,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Usar cámara'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: siomaRed,
                        foregroundColor: siomaWhite,
                        textStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: _isSaving ? null : _activateCamera,
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text('Cargar imágenes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: siomaDark,
                        foregroundColor: siomaWhite,
                        textStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: _isSaving ? null : _showManualModal,                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_faceRecognitionService.isModelLoaded)
                      Column(
                        children: [
                          CircularProgressIndicator(color: siomaRed),
                          SizedBox(height: 12),
                          Text('Cargando modelo facial, espera unos segundos...', style: TextStyle(fontFamily: 'Montserrat')),
                        ],
                      ),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontFamily: 'Montserrat'),
                      decoration: InputDecoration(
                        labelText: 'Nombre completo',
                        labelStyle: const TextStyle(fontFamily: 'Montserrat', color: siomaRed),
                        filled: true,
                        fillColor: siomaGray,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cedulaController,
                      style: const TextStyle(fontFamily: 'Montserrat'),
                      decoration: InputDecoration(
                        labelText: 'Cédula',
                        labelStyle: const TextStyle(fontFamily: 'Montserrat', color: siomaRed),
                        filled: true,
                        fillColor: siomaGray,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cargoController,
                      style: const TextStyle(fontFamily: 'Montserrat'),
                      decoration: InputDecoration(
                        labelText: 'Cargo',
                        labelStyle: const TextStyle(fontFamily: 'Montserrat', color: siomaRed),
                        filled: true,
                        fillColor: siomaGray,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: siomaRed,
                        foregroundColor: siomaWhite,
                        minimumSize: const Size(double.infinity, 50),
                        textStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: _isSaving
                          ? null
                          : !_faceRecognitionService.isModelLoaded
                              ? null
                              : (_nameController.text.isEmpty || _cedulaController.text.isEmpty || _cargoController.text.isEmpty)
                                  ? null
                                  : _processAllImages,
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withAlpha(128),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Guardando...', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Montserrat')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}