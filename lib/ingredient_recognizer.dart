import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile == null) return;
    setState(() => _image = File(pickedFile.path));
    await _analyzeImage(_image!);
  }

  Future<void> _analyzeImage(File image) async {
    setState(() {
      _loading = true;
      _result = "";
    });

    try {
      final inputImage = InputImage.fromFile(image);
      final labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.6)
      );
      final labels = await labeler.processImage(inputImage);
      await labeler.close();

      if (labels.isEmpty) {
        setState(() {
          _result = "No se detectó ningún ingrediente.";
        });
        return;
      }

      final bestLabel = labels.first;
      final ingredientName = bestLabel.label.toLowerCase();
      
      setState(() {
        _result = "Ingrediente detectado: ${bestLabel.label}\nConfianza: ${(bestLabel.confidence * 100).toStringAsFixed(1)}%";
      });

      // Preguntar si quiere guardarlo
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ingrediente detectado'),
          content: Text('¿Quieres agregar "${bestLabel.label}" a tu alacena?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, agregar'),
            ),
          ],
        ),
      );

      if (shouldSave == true) {
        await _repo.addItem(ingredientName, source: 'image_recognition');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${bestLabel.label} agregado a tu alacena'),
              action: SnackBarAction(
                label: 'Ver alacena',
                onPressed: () => Navigator.pushNamed(context, '/pantry'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _result = "Error al analizar la imagen: $e";
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reconocer Ingrediente"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/pantry'),
            icon: const Icon(Icons.kitchen),
            tooltip: 'Ver alacena',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Instrucciones
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.camera_alt, color: Colors.green[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Reconocimiento de ingredientes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kIsWeb 
                      ? 'Selecciona una foto de un ingrediente individual para identificarlo automáticamente'
                      : 'Toma una foto de un ingrediente individual para identificarlo automáticamente',
                    style: TextStyle(color: Colors.green[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Vista previa de imagen
            if (_image != null) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb 
                    ? Image.network(_image!.path, height: 250, fit: BoxFit.cover)
                    : Image.file(_image!, height: 250, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Estado de carga
            if (_loading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Analizando imagen...'),
              const SizedBox(height: 24),
            ],
            
            // Resultado
            if (_result.isNotEmpty && !_loading) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  _result,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Botón para tomar/seleccionar foto
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: Icon(kIsWeb ? Icons.photo_library : Icons.camera_alt),
                label: Text(kIsWeb ? "Seleccionar imagen" : "Tomar foto"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Botón para ver alacena
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/pantry'),
                icon: const Icon(Icons.kitchen),
                label: const Text("Ver mi alacena"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}