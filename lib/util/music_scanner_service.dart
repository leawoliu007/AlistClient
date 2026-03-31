import 'dart:async';

import 'package:alist/database/alist_database_controller.dart';
import 'package:alist/database/table/music_library.dart';
import 'package:alist/database/table/music_track.dart';
import 'package:alist/entity/file_list_resp_entity.dart';
import 'package:alist/net/dio_utils.dart';
import 'package:alist/util/file_type.dart';
import 'package:alist/util/file_utils.dart';
import 'package:alist/util/user_controller.dart';
import 'package:get/get.dart';

class MusicScannerService extends GetxService {
  static MusicScannerService get instance => Get.find<MusicScannerService>();

  final AlistDatabaseController _dbController = Get.find();
  final UserController _userController = Get.find();

  final RxBool isScanning = false.obs;
  final RxString scanStatus = "".obs;
  
  // Scans an existing MusicLibrary
  Future<void> scanLibrary(MusicLibrary library) async {
    if (isScanning.value) return;

    isScanning.value = true;
    scanStatus.value = "Starting scan: ${library.name} ...";
    
    try {
      await _scanLibraryCore(library);
      scanStatus.value = "Scan complete.";
    } catch (e) {
      scanStatus.value = "Scan failed: $e";
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        isScanning.value = false;
        scanStatus.value = "";
      });
    }
  }

  Future<void> scanAllLibraries() async {
    if (isScanning.value) return;

    final user = _userController.user.value;
    final libs = await _dbController.musicLibraryDao.findLibraries(user.serverUrl, user.username);
    if (libs.isEmpty) return;

    isScanning.value = true;
    try {
      for (var lib in libs) {
        scanStatus.value = "Scanning library: ${lib.name} ...";
        await _scanLibraryCore(lib);
      }
      scanStatus.value = "Global Scan complete.";
    } catch (e) {
      scanStatus.value = "Global Scan failed: $e";
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        isScanning.value = false;
        scanStatus.value = "";
      });
    }
  }

  Future<void> _scanLibraryCore(MusicLibrary library) async {
    List<MusicTrack> tracksToSave = [];
    await _scanDirectory(library.remotePath, library, tracksToSave, 0);
    
    // Save to database
    scanStatus.value = "Saving ${tracksToSave.length} tracks to database...";
    if (library.id != null) {
      await _dbController.musicTrackDao.replaceAllTracksForLibrary(library.id!, tracksToSave);
    }
  }

  Future<void> _scanDirectory(String path, MusicLibrary library, List<MusicTrack> accTracks, int depth) async {
    if (!isScanning.value) return; 
    
    // Normalize path: ensure no trailing slash unless it's root
    String normalizedPath = path;
    if (normalizedPath.length > 1 && normalizedPath.endsWith('/')) {
      normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
    }

    scanStatus.value = "Scanning (Depth $depth): $normalizedPath... (Tracks: ${accTracks.length})";
    
    var body = {
      "path": normalizedPath,
      "password": "", 
      "page": 1,
      "per_page": 0,
      "refresh": false
    };

    final completer = Completer<void>();
    
    DioUtils.instance.requestNetwork<FileListRespEntity>(
      Method.post, 
      "fs/list", 
      params: body,
      onSuccess: (data) async {
        try {
          if (data == null) {
             return;
          }

          var contents = data.content ?? [];
          String provider = data.provider ?? "";
          
          for (var file in contents) {
            if (file.isDir) {
              // Check max depth before recursing
              if (depth < library.maxDepth) {
                String subPath = _combinePath(normalizedPath, file.name);
                await _scanDirectory(subPath, library, accTracks, depth + 1);
              }
            } else {
              if (file.getFileType() == FileType.audio) {
                accTracks.add(_fileToTrack(file, normalizedPath, library, provider, data));
              }
            }
          }
        } catch (e) {
          LogUtil.e("Scan internal error for $normalizedPath: $e");
        } finally {
          completer.complete();
        }
      },
      onError: (code, msg) {
        LogUtil.e("Scan network error for $normalizedPath: $code - $msg");
        completer.complete();
      }
    );
    
    await completer.future;
  }
  
  String _combinePath(String parent, String name) {
    if (parent == '/') return '/$name';
    if (parent.endsWith('/')) return '$parent$name';
    return '$parent/$name';
  }

  MusicTrack _fileToTrack(FileListRespContent file, String parentPath, MusicLibrary library, String provider, FileListRespEntity data) {
    var user = _userController.user.value;
    DateTime? modifyTime = file.parseModifiedTime();
    
    return MusicTrack(
      name: file.name,
      remotePath: _combinePath(parentPath, file.name),
      libraryId: library.id ?? -1,
      size: file.size ?? 0,
      sign: file.sign,
      thumb: file.thumb,
      modified: modifyTime?.millisecondsSinceEpoch ?? 0,
      provider: provider,
      serverUrl: user.serverUrl,
      userId: user.username,
      createTime: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
