# 📱 Instrucciones para Exportar APK de VISER

## 🔧 Preparación del Entorno

### 1. Verificar que Flutter esté instalado
```bash
flutter doctor
```
Asegúrate de que todos los checks estén en verde ✅

### 2. Limpiar el proyecto
```bash
flutter clean
flutter pub get
```

## 🏗️ Generar APK de Desarrollo (Debug)

### Para pruebas rápidas:
```bash
flutter build apk --debug
```
El APK se genera en: `build/app/outputs/flutter-apk/app-debug.apk`

## 🚀 Generar APK de Producción (Release)

### 1. APK Universal (recomendado)
```bash
flutter build apk --release
```

### 2. APK por arquitectura (menor tamaño)
```bash
flutter build apk --split-per-abi --release
```

## 📍 Ubicación de los APKs generados

Los APKs se generan en:
```
build/app/outputs/flutter-apk/
├── app-release.apk           (Universal - recomendado)
├── app-arm64-v8a-release.apk (64-bit ARM - mayoría de dispositivos modernos)
├── app-armeabi-v7a-release.apk (32-bit ARM - dispositivos más antiguos)
└── app-x86_64-release.apk    (Emuladores x86)
```

## 🎯 APK Recomendado para Distribución

**Usar: `app-release.apk`** - Es universal y funciona en todos los dispositivos Android.

## 📋 Información de la Aplicación

- **Nombre**: VISER
- **Package**: com.sioma.viser
- **Versión**: 1.0.0
- **Build**: 1

## 🔒 Configuración de Firma (Opcional para Producción)

Para un APK firmado profesionalmente (Play Store):

### 1. Crear keystore
```bash
keytool -genkey -v -keystore viser-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias viser
```

### 2. Configurar en android/key.properties
```properties
storePassword=TU_PASSWORD
keyPassword=TU_PASSWORD
keyAlias=viser
storeFile=../viser-key.jks
```

### 3. Modificar android/app/build.gradle.kts para usar la firma

### 4. Generar APK firmado
```bash
flutter build apk --release
```

## 🚦 Comandos Paso a Paso

1. **Abrir terminal en la carpeta del proyecto**
   ```bash
   cd c:\Users\Daniela\AgroID\agroid
   ```

2. **Limpiar y preparar**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Generar APK**
   ```bash
   flutter build apk --release
   ```

4. **Ubicar el APK**
   El archivo estará en:
   ```
   build\app\outputs\flutter-apk\app-release.apk
   ```

## 📱 Instalación del APK

### En dispositivo Android:
1. Habilitar "Orígenes desconocidos" en Configuración > Seguridad
2. Transferir el APK al dispositivo
3. Tocar el archivo APK para instalar

### Vía ADB:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

## ⚠️ Notas Importantes

- El APK de **release** es optimizado y más pequeño
- El APK de **debug** es más grande pero incluye herramientas de desarrollo
- Para distribución comercial, usar APK firmado
- El APK universal funciona en todos los dispositivos pero es más pesado
- Los APK por arquitectura son más ligeros pero específicos

## 🎉 ¡Listo!

Tu aplicación VISER estará lista para instalar en cualquier dispositivo Android.

**Tamaño aproximado del APK**: 15-25 MB (dependiendo de las optimizaciones)
