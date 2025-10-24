import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  Interpreter? _interpreter;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite');
    } catch (e) {
      // print("Error al cargar el modelo: $e");
    }
  }

  Future<List<double>> processImage(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception("No se pudo decodificar la imagen.");
    }

    // Redimensionar la imagen a 112x112
    final resizedImage = img.copyResize(image, width: 112, height: 112);

    // Normalizar y convertir a formato de entrada del modelo [112, 112, 3]
    final imageMatrix = List.generate(
      112,
      (y) => List.generate(
        112,
        (x) {
          final pixel = resizedImage.getPixel(x, y);
          return [
            (pixel.r - 127.5) / 127.5,
            (pixel.g - 127.5) / 127.5,
            (pixel.b - 127.5) / 127.5,
          ];
        },
      ),
    );

    // El modelo espera una entrada de [1, 112, 112, 3]
    final input = [imageMatrix];
    // La salida será [1, 192]
    final output = List.filled(1 * 192, 0.0).reshape([1, 192]);

    if (_interpreter == null) {
      throw Exception("El intérprete de TFLite no está inicializado.");
    }

    _interpreter!.run(input, output);

    // Devolver el embedding como una lista de doubles
    final embedding = (output[0] as List<dynamic>).cast<double>();
    return embedding;
  }
}