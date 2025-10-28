import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:viser/config/theme/theme.dart';
import 'package:viser/domain/services/database_service.dart';
import 'package:viser/domain/services/face_recognition_service.dart';
import 'package:viser/presentation/screens/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Captura errores globales
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('❌ Flutter Error: ${details.exception}');
  };

  await runZonedGuarded(() async {
    print('🚀 Iniciando VISER...');

    // Inicializar Hive
    print('📦 Inicializando Hive...');
    await Hive.initFlutter();
    // Si necesitas limpiar cajas antiguas descomenta:
    // await Hive.deleteBoxFromDisk('work_logs');
    // await Hive.deleteBoxFromDisk('registered_workers');

    // Inicializar base de datos
    print('💾 Inicializando base de datos...');
    final dbService = DatabaseService();
    await dbService.init();
    print('✅ Base de datos lista');

    // Inicializar servicio de reconocimiento facial
    print('🤖 Cargando modelo de reconocimiento facial...');
    final faceRecognitionService = FaceRecognitionService();
    await faceRecognitionService.loadModel();
    print('✅ Modelo cargado correctamente');

    // Ejecutar aplicación
    runApp(MyApp(faceRecognitionService: faceRecognitionService));
  }, (error, stackTrace) {
    debugPrint('🔥 Error no controlado: $error');
  });
}

class MyApp extends StatelessWidget {
  final FaceRecognitionService faceRecognitionService;

  const MyApp({super.key, required this.faceRecognitionService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VISER',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: HomePage(faceRecognitionService: faceRecognitionService),
      // Si deseas usar Material 3 y adaptaciones automáticas
      themeMode: ThemeMode.light,
    );
  }
}
