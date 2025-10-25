import 'package:viser/config/theme/theme.dart';
import 'package:viser/domain/services/database_service.dart';
import 'package:viser/domain/services/face_recognition_service.dart';
import 'package:viser/presentation/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  // Asegurarse de que los bindings de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();
  print('🚀 Iniciando AgroID...');

  // TEMPORAL: Forzar eliminación de cajas antiguas para resolver problemas de migración
  try {
    print('📦 Inicializando Hive...');
    await Hive.initFlutter();
    // await Hive.deleteBoxFromDisk('work_logs');
    // await Hive.deleteBoxFromDisk('registered_workers');
    print('✅ Cajas antiguas eliminadas exitosamente');
  } catch (e) {
    print('⚠️ No se pudieron eliminar las cajas (probablemente no existen): $e');
  }

  // Inicializar la base de datos
  print('💾 Inicializando base de datos...');
  final dbService = DatabaseService();
  await dbService.init();
  print('✅ Base de datos inicializada');

  // Cargar el modelo de reconocimiento facial
  print('🤖 Cargando modelo de reconocimiento facial...');
  final faceRecognitionService = FaceRecognitionService();
  await faceRecognitionService.loadModel();
  print('✅ Modelo cargado exitosamente');

  print('🎉 Iniciando aplicación...');
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
