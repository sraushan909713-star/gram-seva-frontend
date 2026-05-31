// lib/core/utils/cloudinary_url.dart
// ──────────────────────────────────────────────────────────────────
// Cloudinary URL transformation helper.
//
// Cloudinary supports inline image transformations via URL segments
// like /w_500,q_auto,f_auto/. This helper injects the right transform
// for each rendering context (avatar / thumbnail / full-screen).
//
// q_auto = automatic quality (Cloudinary picks the best compression).
// f_auto = automatic format (WebP/AVIF on supported clients).
// c_limit = shrink to fit, never enlarge.
// c_fill  = crop to fill exact dimensions (used for circular avatars).
//
// Together these typically reduce image bytes by 60–80%.
// ──────────────────────────────────────────────────────────────────

class CloudinaryUrl {
  // ──────────────────────────────────────────────────────────────
  // Square crop for circular avatars / profile pictures.
  // Default 160px handles 2x retina for 80px display avatars.
  // For tiny avatars (~30px) you can pass size: 120.
  // ──────────────────────────────────────────────────────────────
  static String avatar(String url, {int size = 160}) {
    return _inject(url, 'w_$size,h_$size,c_fill,q_auto,f_auto');
  }

  // ──────────────────────────────────────────────────────────────
  // Card thumbnail — feed images, list previews.
  // Width-limited, preserves aspect ratio.
  // ──────────────────────────────────────────────────────────────
  static String thumb(String url, {int width = 500}) {
    return _inject(url, 'w_$width,c_limit,q_auto,f_auto');
  }

  // ──────────────────────────────────────────────────────────────
  // Full-screen photo viewer — detail screens, photo carousels.
  // ──────────────────────────────────────────────────────────────
  static String full(String url, {int width = 1080}) {
    return _inject(url, 'w_$width,c_limit,q_auto,f_auto');
  }

  // ──────────────────────────────────────────────────────────────
  // Just optimize format + quality, no resizing.
  // Use when you don't know the display size ahead of time.
  // ──────────────────────────────────────────────────────────────
  static String optimized(String url) {
    return _inject(url, 'q_auto,f_auto');
  }

  // ──────────────────────────────────────────────────────────────
  // Internal: insert a transformation segment after /upload/.
  // Safely passes through non-Cloudinary URLs unchanged.
  // ──────────────────────────────────────────────────────────────
  static String _inject(String url, String transformation) {
    if (!url.contains('res.cloudinary.com') || !url.contains('/upload/')) {
      return url;
    }
    // Avoid double-injection if a transform is already present.
    if (RegExp(r'/upload/[a-z]_').hasMatch(url)) {
      return url;
    }
    return url.replaceFirst('/upload/', '/upload/$transformation/');
  }
}
