import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import '../services/document_action_service.dart';
import '../utils/app_snackbar.dart';
import 'pdf_viewer_screen.dart';

// ---------------------------------------------------------------------------
// SurveyDocumentTile
// ---------------------------------------------------------------------------

/// Displays a single Permission Document (PDF/image) with:
///   • A view icon (for PDFs) that opens [PdfViewerScreen].
///   • A download/share icon that downloads the file and triggers OS share sheet.
///
/// For non-PDF documents (images etc.) the view action is hidden; only
/// the download/share is available.
class SurveyDocumentTile extends ConsumerStatefulWidget {
  final String storagePath;
  final String originalFileName;
  final String fileType;
  final int sizeBytes;

  /// If true, a thin bottom divider is NOT drawn.
  final bool isLast;

  const SurveyDocumentTile({
    super.key,
    required this.storagePath,
    required this.originalFileName,
    required this.fileType,
    required this.sizeBytes,
    this.isLast = false,
  });

  @override
  ConsumerState<SurveyDocumentTile> createState() => _SurveyDocumentTileState();
}

class _SurveyDocumentTileState extends ConsumerState<SurveyDocumentTile> {
  bool _isViewing = false;
  bool _isDownloading = false;

  bool get _isPdf => widget.fileType.toLowerCase() == 'pdf';

  // ---------------------------------------------------------------------------
  // View PDF action
  // ---------------------------------------------------------------------------
  Future<void> _openPdf() async {
    if (_isViewing || _isDownloading) return;
    setState(() => _isViewing = true);
    try {
      final service = ref.read(documentActionServiceProvider);
      final localPath = await service.downloadPdfForViewing(
        storagePath: widget.storagePath,
        fileName: widget.originalFileName,
        onProgress: (_) {}, // progress handled by loading state
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            localPath: localPath,
            fileName: widget.originalFileName,
          ),
        ),
      );
    } on DocumentActionException catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Cannot Open PDF',
          message: e.message,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Error',
          message: 'An unexpected error occurred. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isViewing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Download / share action
  // ---------------------------------------------------------------------------
  Future<void> _shareDocument() async {
    if (_isViewing || _isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final service = ref.read(documentActionServiceProvider);
      await service.shareKmlFile(
        storagePath: widget.storagePath,
        fileName: widget.originalFileName,
      );
    } on DocumentActionException catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Download Failed',
          message: e.message,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Error',
          message: 'An unexpected error occurred. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = _isViewing || _isDownloading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: 4.h,
          ),
          leading: Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: _fileIconColor(colorScheme).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              _fileIcon,
              color: _fileIconColor(colorScheme),
              size: 22.sp,
            ),
          ),
          title: Text(
            widget.originalFileName,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${(widget.sizeBytes / 1024).toStringAsFixed(1)} KB · ${widget.fileType.toUpperCase()}',
            style: TextStyle(
              fontSize: 11.sp,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: isLoading
              ? SizedBox(
                  width: 72.w,
                  child: Center(
                    child: SizedBox(
                      width: 18.sp,
                      height: 18.sp,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                )
              : _buildActions(colorScheme),
        ),
        if (!widget.isLast)
          Divider(
            height: 1,
            indent: 14.w,
            endIndent: 14.w,
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
      ],
    );
  }

  Widget _buildActions(ColorScheme colorScheme) {
    return SizedBox(
      width: _isPdf ? 80.w : 40.w,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isPdf)
            _ActionButton(
              icon: Icons.visibility_outlined,
              tooltip: 'View PDF',
              color: colorScheme.primary,
              onTap: _openPdf,
            ),
          _ActionButton(
            icon: Icons.download_outlined,
            tooltip: 'Download / Share',
            color: colorScheme.secondary,
            onTap: _shareDocument,
          ),
        ],
      ),
    );
  }

  IconData get _fileIcon {
    switch (widget.fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _fileIconColor(ColorScheme cs) {
    switch (widget.fileType.toLowerCase()) {
      case 'pdf':
        return cs.error;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return cs.tertiary;
      default:
        return cs.primary;
    }
  }
}

// ---------------------------------------------------------------------------
// KmlFileTile — for KML/KMZ documents
// ---------------------------------------------------------------------------

/// Displays the KML/KMZ boundary file row with download/share only
/// (KML files are not viewable in-app; they open in Google Earth etc.)
class KmlFileTile extends ConsumerStatefulWidget {
  final String storagePath;
  final String originalFileName;
  final String fileType;
  final int sizeBytes;

  const KmlFileTile({
    super.key,
    required this.storagePath,
    required this.originalFileName,
    required this.fileType,
    required this.sizeBytes,
  });

  @override
  ConsumerState<KmlFileTile> createState() => _KmlFileTileState();
}

class _KmlFileTileState extends ConsumerState<KmlFileTile> {
  bool _isDownloading = false;

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final service = ref.read(documentActionServiceProvider);
      await service.shareKmlFile(
        storagePath: widget.storagePath,
        fileName: widget.originalFileName,
      );
    } on DocumentActionException catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Download Failed',
          message: e.message,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Error',
          message: 'An unexpected error occurred. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.map_outlined,
              color: colorScheme.primary,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.originalFileName,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  '${(widget.sizeBytes / 1024).toStringAsFixed(1)} KB · ${widget.fileType.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          if (_isDownloading)
            SizedBox(
              width: 20.sp,
              height: 20.sp,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          else
            _ActionButton(
              icon: Icons.download_outlined,
              tooltip: 'Download KML/KMZ',
              color: colorScheme.primary,
              onTap: _download,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small reusable action icon button
// ---------------------------------------------------------------------------
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Icon(icon, size: 20.sp, color: color),
        ),
      ),
    );
  }
}
