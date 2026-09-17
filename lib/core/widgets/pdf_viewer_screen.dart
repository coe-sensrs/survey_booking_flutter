import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/app_snackbar.dart';

/// A full-screen PDF viewer that:
///   • Loads a local file at [localPath] (pre-downloaded by the caller)
///   • Displays current page / total pages in the app bar
///   • Provides a share / download button in the app bar so users can save the
///     PDF to their device or open it in another app.
class PdfViewerScreen extends ConsumerStatefulWidget {
  /// Absolute local file path of the PDF, already downloaded.
  final String localPath;

  /// Display name shown in the app bar title.
  final String fileName;

  const PdfViewerScreen({
    super.key,
    required this.localPath,
    required this.fileName,
  });

  /// Named route path for go_router registration if needed.
  static const routeName = '/pdf-viewer';

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isReady = false;
  String? _loadError;

  bool _isSharing = false;

  // ---------------------------------------------------------------------------
  // Share / download the current PDF
  // ---------------------------------------------------------------------------
  Future<void> _shareFile() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(widget.localPath)], subject: widget.fileName),
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Share Failed',
          message: 'Could not share the file. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final pageLabel = _totalPages > 0
        ? 'Page ${_currentPage + 1} / $_totalPages'
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            if (pageLabel.isNotEmpty)
              Text(
                pageLabel,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          if (_isSharing)
            Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: SizedBox(
                width: 20.sp,
                height: 20.sp,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onSurface,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Download / Share PDF',
              icon: const Icon(Icons.download_outlined),
              onPressed: _isReady ? _shareFile : null,
            ),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    // Error state
    if (_loadError != null) {
      return _ErrorView(
        message: _loadError!,
        onRetry: () => setState(() {
          _loadError = null;
          _isReady = false;
        }),
      );
    }

    final fileExists = File(widget.localPath).existsSync();
    if (!fileExists) {
      return _ErrorView(
        message: 'The PDF file could not be found on this device.',
        onRetry: null,
      );
    }

    return Stack(
      children: [
        PDFView(
          filePath: widget.localPath,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          pageSnap: true,
          fitEachPage: true,
          fitPolicy: FitPolicy.BOTH,
          onRender: (pages) {
            if (mounted) {
              setState(() {
                _totalPages = pages ?? 0;
                _isReady = true;
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _loadError = 'Failed to render PDF: $error';
              });
            }
          },
          onPageError: (page, error) {
            if (mounted) {
              AppSnackbar.showError(
                context,
                title: 'Page Error',
                message: 'Page ${(page ?? 0) + 1} failed to load.',
              );
            }
          },
          onViewCreated: (_) {}, // reserved for future page-jump control
          onPageChanged: (page, total) {
            if (mounted) {
              setState(() {
                _currentPage = page ?? 0;
                _totalPages = total ?? 0;
              });
            }
          },
        ),
        if (!_isReady && _loadError == null)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorView({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 64.sp,
              color: colorScheme.error,
            ),
            SizedBox(height: 16.h),
            Text(
              'Could Not Load PDF',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 20.h),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
