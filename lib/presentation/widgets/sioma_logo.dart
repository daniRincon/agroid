import 'package:flutter/material.dart';
import 'package:viser/config/theme/theme.dart';

class SiomaLogo extends StatelessWidget {
  final double size;

  const SiomaLogo({super.key, this.size = 150});

  @override
  Widget build(BuildContext context) {
    // TODO: Reemplazar este placeholder con la imagen del logo de SIOMA.
    // 1. La carpeta 'assets/' ya ha sido creada.
    // 2. Agrega tu archivo de logo (ej. 'assets/sioma_logo.png').
    // 3. La carpeta 'assets/' ya está declarada en tu archivo pubspec.yaml.
    // 4. Descomenta la siguiente línea y ajusta la ruta:
    // return Image.asset('assets/sioma_logo.png', width: size);

    return Text(
      'SIOMA',
      style: TextStyle(
        fontSize: size / 3,
        fontWeight: FontWeight.bold,
        color: AppTheme.primary, // Color primario de SIOMA
      ),
    );
  }
}