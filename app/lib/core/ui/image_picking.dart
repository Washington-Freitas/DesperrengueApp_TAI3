import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_theme.dart';
import 'widgets.dart';
import '../services/media_service.dart';

class PickedImage {
  const PickedImage(this.bytes, this.ext, this.name);
  final Uint8List bytes;
  final String ext;
  final String name;
}

final ImagePicker _picker = ImagePicker();

/// Abre câmera ou galeria. Devolve null se o usuário cancelar ou negar permissão.
Future<PickedImage?> pickImage(BuildContext context, {ImageSource? source}) async {
  var src = source;
  src ??= await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (src == null) return null;
  try {
    final file = await _picker.pickImage(source: src, maxWidth: 1600, imageQuality: 82);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedImage(bytes, MediaService.extOf(file.name), file.name);
  } catch (e) {
    if (context.mounted) {
      showSnack(context, 'Não foi possível acessar a câmera/galeria. Verifique as permissões.', error: true);
    }
    return null;
  }
}

/// Grade "+ Adicionar" com miniaturas removíveis (pedido e suporte).
class MediaPickerRow extends StatelessWidget {
  const MediaPickerRow({
    super.key,
    required this.images,
    required this.onAdd,
    required this.onRemove,
    this.max = 4,
  });

  final List<PickedImage> images;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final int max;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (images.length < max)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 92,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFB8BCC6)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: AppColors.muted),
                    SizedBox(height: 4),
                    Text('Adicionar', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
          for (var i = 0; i < images.length; i++)
            Stack(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    image: DecorationImage(image: MemoryImage(images[i].bytes), fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  right: 14,
                  top: 4,
                  child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: const CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.black87,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
