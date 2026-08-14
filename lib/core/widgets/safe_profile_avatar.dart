import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:survey_desk/core/services/firebase_app_check_setup.dart';

class SafeProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final Color? iconColor;

  const SafeProfileAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 20,
    this.fallbackIcon = Icons.person,
    this.backgroundColor,
    this.iconColor,
  });

  // Revised approach for robust error handling
  Widget _buildSafeImage() {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          httpHeaders: FirebaseAppCheckSetup.httpHeaders,
          errorWidget: (context, url, error) {
            return _buildFallbackContainer();
          },
          progressIndicatorBuilder: (context, url, downloadProgress) {
            return Center(
              child: CircularProgressIndicator(
                value: downloadProgress.progress,
                strokeWidth: 2,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[200],
      child: Icon(
        fallbackIcon,
        size: radius * 1.2,
        color: iconColor ?? Colors.grey[400],
      ),
    );
  }

  Widget _buildFallbackContainer() {
    return Container(
      color: backgroundColor ?? Colors.grey[200],
      child: Center(
        child: Icon(
          fallbackIcon,
          size: radius * 1.2,
          color: iconColor ?? Colors.grey[400],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Override to use _buildSafeImage with robust validation of URL schema
    if (imageUrl == null ||
        imageUrl!.isEmpty ||
        (!imageUrl!.startsWith('http://') &&
            !imageUrl!.startsWith('https://'))) {
      return _buildFallback();
    }
    return _buildSafeImage();
  }
}
