import 'package:share_plus/share_plus.dart';

abstract class FileOpenService {
  Future<bool> openFile(String filePath);
}

class MobileFileOpenService implements FileOpenService {
  @override
  Future<bool> openFile(String filePath) async {
    try {
      // ignore: deprecated_member_use
      final result = await Share.shareXFiles([XFile(filePath)]);
      return result.status == ShareResultStatus.success;
    } catch (_) {
      return false;
    }
  }
}
