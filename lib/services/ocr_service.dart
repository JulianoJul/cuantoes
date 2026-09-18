import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  Future<String> reconocerTexto(String rutaImagen) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(rutaImagen);
      final resultado = await recognizer.processImage(input);
      return resultado.text;
    } finally {
      await recognizer.close();
    }
  }
}
