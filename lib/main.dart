import 'package:agroid/config/theme/theme.dart';
import 'package:agroid/domain/services/database_service.dart';
import 'package:agroid/domain/services/face_recognition_service.dart';
import 'package:agroid/presentation/screens/home_page.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  // Asegurarse de que los bindings de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar la base de datos
  final dbService = DatabaseService();
  await dbService.init();

  // Cargar el modelo de reconocimiento facial
  final faceRecognitionService = FaceRecognitionService();
  await faceRecognitionService.loadModel();

  runApp(MyApp(faceRecognitionService: faceRecognitionService));
}

class MyApp extends StatelessWidget {
  final FaceRecognitionService faceRecognitionService;

  const MyApp({super.key, required this.faceRecognitionService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroID',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: HomePage(faceRecognitionService: faceRecognitionService),
    );
  }
}
