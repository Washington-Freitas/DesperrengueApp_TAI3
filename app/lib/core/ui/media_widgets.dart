import 'package:flutter/material.dart';

import '../models/marketplace_models.dart';
import '../services/media_service.dart';
import 'app_theme.dart';

IconData categoryIcon(String name) {
  switch (name) {
    case 'Elétrica':
      return Icons.bolt_rounded;
    case 'Encanador':
      return Icons.water_drop_rounded;
    case 'Limpeza':
      return Icons.cleaning_services_rounded;
    case 'Montagem':
      return Icons.chair_alt_rounded;
    case 'Pintura':
      return Icons.format_paint_rounded;
    case 'Chaveiro':
      return Icons.key_rounded;
    case 'Pedreiro':
      return Icons.construction_rounded;
    case 'Gesso':
      return Icons.layers_rounded;
    case 'Marcenaria':
      return Icons.carpenter_rounded;
    default:
      return Icons.handyman_rounded;
  }
}

Color categoryColor(String name) {
  for (final c in kCategories) {
    if (c.name == name) return Color(c.colorValue);
  }
  return AppColors.surface;
}

/// Imagem de bucket PRIVADO (URL assinada, com cache).
class SignedImage extends StatelessWidget {
  const SignedImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 12,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: FutureBuilder<String?>(
          future: MediaService().signedUrl(path),
          builder: (context, snap) {
            final url = snap.data;
            if (url == null) {
              return Container(
                color: AppColors.surface,
                child: Center(
                  child: snap.connectionState == ConnectionState.done
                      ? const Icon(Icons.broken_image_outlined, color: AppColors.muted)
                      : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            return Image.network(url, fit: fit, width: width, height: height,
                errorBuilder: (_, _, _) => Container(
                      color: AppColors.surface,
                      child: const Icon(Icons.broken_image_outlined, color: AppColors.muted),
                    ));
          },
        ),
      ),
    );
  }
}

/// Imagem de bucket PÚBLICO (portfólio/avatar) a partir do caminho salvo.
class PublicImage extends StatelessWidget {
  const PublicImage({super.key, required this.path, this.width, this.height, this.fit = BoxFit.cover, this.radius = 12});

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = path.startsWith('http') ? path : MediaService().publicUrl(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => Container(
          width: width,
          height: height,
          color: AppColors.surface,
          child: const Icon(Icons.broken_image_outlined, color: AppColors.muted),
        ),
      ),
    );
  }
}
