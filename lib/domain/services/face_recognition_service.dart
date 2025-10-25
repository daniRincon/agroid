import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  Interpreter? _interpreter;

  static const double similarityThreshold = 0.78;

  Future<void> loadModel() async {
    try {
      // Usar solo el modelo estándar MobileFaceNet
      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite');
    } catch (e) {
      // print("Error al cargar el modelo: $e");
    }
  }

  bool get isModelLoaded => _interpreter != null;

  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw Exception("Los embeddings deben tener la misma longitud");
    }
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }
    return dotProduct / (norm1 == 0 || norm2 == 0 ? 1 : (sqrt(norm1) * sqrt(norm2)));
  }

  List<double> _normalizeL2(List<double> embedding) {
    double norm = sqrt(embedding.fold(0.0, (sum, val) => sum + val * val));
    if (norm == 0) return embedding;
    return embedding.map((e) => e / norm).toList();
  }

  Future<List<double>> processImage(XFile imageFile, {bool skipFrameCheck = false}) async {
    print('Procesando imagen...');
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      print('Error: No se pudo decodificar la imagen.');
      throw Exception("No se pudo decodificar la imagen.");
    }
    final resizedImage = img.copyResize(image, width: 112, height: 112);
    print('Imagen redimensionada a 112x112');
    final imageMatrix = List.generate(
      112,
      (y) => List.generate(
        112,
        (x) {
          final pixel = resizedImage.getPixel(x, y);
          return [
            (pixel.r - 127.5) / 128.0,
            (pixel.g - 127.5) / 128.0,
            (pixel.b - 127.5) / 128.0,
          ];
        },
      ),
    );
    print('Matriz de imagen generada, ejecutando modelo...');
    final input = [imageMatrix];
    final output = List.filled(1 * 128, 0.0).reshape([1, 128]);
    if (_interpreter == null) {
      print('Error: El intérprete de TFLite no está inicializado.');
      throw Exception("El intérprete de TFLite no está inicializado.");
    }
    _interpreter!.run(input, output);
    print('Inferencia completada, output: ' + output.toString());
    final embedding = (output[0] as List<dynamic>).cast<double>();
    final normalizedEmbedding = _normalizeL2(embedding);
    print('Embedding generado y normalizado: ' + normalizedEmbedding.toString());
    return normalizedEmbedding;
  }

  Future<List<double>> processImageFromFile(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception("No se pudo decodificar la imagen.");
    }
    final resizedImage = img.copyResize(image, width: 112, height: 112);
    final imageMatrix = List.generate(
      112,
      (y) => List.generate(
        112,
        (x) {
          final pixel = resizedImage.getPixel(x, y);
          return [
            (pixel.r - 127.5) / 128.0,
            (pixel.g - 127.5) / 128.0,
            (pixel.b - 127.5) / 128.0,
          ];
        },
      ),
    );
    final input = [imageMatrix];
    final output = List.filled(1 * 128, 0.0).reshape([1, 128]);
    if (_interpreter == null) {
      throw Exception("El intérprete de TFLite no está inicializado.");
    }
    _interpreter!.run(input, output);
    final embedding = (output[0] as List<dynamic>).cast<double>();
    final normalizedEmbedding = _normalizeL2(embedding);
    return normalizedEmbedding;
  }
}