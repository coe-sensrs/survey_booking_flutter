import 'package:share_plus/share_plus.dart';

abstract class FileOpenService {
  Future<bool> openFile(String filePath);
}

class MobileFileOpenService implements FileOpenService {
  @override
  Future<bool> openFile(String filePath) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(files: [XFile(filePath)]),
      );
      return result.status == ShareResultStatus.success;
    } catch (_) {
      return false;
    }
  }
}
