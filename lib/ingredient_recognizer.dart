import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'services/pantry_repository.dart';

class IngredientRecognizer extends StatefulWidget {
  const IngredientRecognizer({super.key});

  @override
  State<IngredientRecognizer> createState() => _IngredientRecognizerState();
}

class _IngredientRecognizerState extends State<IngredientRecognizer> {
  File? _image;
  String _result = "";
  bool _loading = false;
  final _repo = PantryRepository();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile == null) return;
    setState(() => _image = File(pickedFile.path));

    _analyzeImage(_image!);
  }

  Future<void> _analyzeImage(File image) async {
    setState(() {
      _loading = true;
      _result = "";
    });

    final inputImage = InputImage.fromFile(image);
    final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.6));
    final labels = await labeler.processImage(inputImage);

    if (labels.isEmpty) {
      setState(() {
        _loading = false;
        _result = "No se detectó ningún ingrediente.";
      });
      return;
    }

    final bestLabel = labels.first;
    setState(() {
      _loading = false;
      _result = "Ingrediente detectado: ${bestLabel.label}";
    });

    // Guardar en la alacena del usuario
    await _repo.addItem(bestLabel.label, source: 'camera');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reconocer Ingrediente")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_image != null) Image.file(_image!, height: 200),
            const SizedBox(height: 20),
            if (_loading) const CircularProgressIndicator(),
            if (_result.isNotEmpty) Text(_result, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text("Tomar foto de ingrediente"),
            ),
          ],
        ),
      ),
    );
  }
}
