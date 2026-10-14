import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

/// Network image via CachedNetworkImage.
///
/// [storagePath] is a Supabase storage path; [bucket] identifies the bucket.
/// Pass [aspectRatio] to constrain the image (default 1:1 per product cards).
class CachedImage extends StatelessWidget {
  const CachedImage({
    super.key,
    required this.storagePath,
    this.bucket = 'product-images',
    this.aspectRatio = 1.0,
    this.borderRadius = AppRadius.card,
    this.fit = BoxFit.cover,
  });

  final String? storagePath;
  final String bucket;
  final double aspectRatio;
  final double borderRadius;
  final BoxFit fit;

  String? get _publicUrl {
    if (storagePath == null || storagePath!.isEmpty) return null;
    return Supabase.instance.client.storage
        .from(bucket)
        .getPublicUrl(storagePath!);
  }

  @override
  Widget build(BuildContext context) {
    final url = _publicUrl;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: fit,
                placeholder: (_, __) => _shimmer(),
                errorWidget: (_, __, ___) => _errorBox(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _shimmer() => Container(
        color: AppColors.outline,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _placeholder() => Container(
        color: AppColors.outline,
        child: const Center(
          child: Icon(Icons.image_outlined,
              color: AppColors.textSecondary, size: 32),
        ),
      );

  Widget _errorBox() => Container(
        color: AppColors.outline,
        child: const Center(
          child: Icon(Icons.broken_image_outlined,
              color: AppColors.textSecondary, size: 32),
        ),
      );
}
