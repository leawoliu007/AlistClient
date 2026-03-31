import 'package:alist/database/alist_database_controller.dart';
import 'package:alist/database/table/music_library.dart';
import 'package:alist/screen/music/music_playlist_screen.dart';
import 'package:alist/util/music_scanner_service.dart';
import 'package:alist/util/user_controller.dart';
import 'package:alist/widget/alist_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
// We use a simple path picker if one exists, but for now we prompt the user to paste a directory path or integrate with standard navigation.
// Given time limits, we'll prompt for an Alist directory path.

class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({Key? key}) : super(key: key);

  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  final AlistDatabaseController _dbController = Get.find();
  final UserController _userController = Get.find();
  final MusicScannerService _scannerService = MusicScannerService.instance;

  List<MusicLibrary> _libraries = [];

  @override
  void initState() {
    super.initState();
    _loadLibraries();
  }

  Future<void> _loadLibraries() async {
    final user = _userController.user.value;
    final libs = await _dbController.musicLibraryDao.findLibraries(user.serverUrl, user.username);
    if (mounted) {
      setState(() {
        _libraries = libs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlistScaffold(
      appbarTitle: const Text("Music Library"),
      appbarActions: [
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: () {
            _scannerService.scanAllLibraries().then((_) => _loadLibraries());
          },
        )
      ],
      body: Column(
        children: [
          Obx(() {
            if (_scannerService.isScanning.value) {
              return Container(
                padding: const EdgeInsets.all(8),
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _scannerService.scanStatus.value,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          Expanded(
            child: _libraries.isEmpty
                ? const Center(child: Text("No Music Libraries added yet.\nPress + to add an Alist folder.", textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: _libraries.length,
                    itemBuilder: (context, index) {
                      final lib = _libraries[index];
                      return ListTile(
                        leading: const Icon(Icons.library_music, size: 40),
                        title: Text(lib.name),
                        subtitle: Text(lib.remotePath),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Depth: ${lib.maxDepth}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                await _dbController.musicTrackDao.deleteTracksByLibraryId(lib.id!);
                                await _dbController.musicLibraryDao.deleteById(lib.id!);
                                _loadLibraries();
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          Get.to(() => MusicPlaylistScreen(library: lib));
                        },
                        onLongPress: () {
                          final TextEditingController _depthController = TextEditingController(text: lib.maxDepth.toString());
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Set Scan Depth"),
                              content: TextField(
                                controller: _depthController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: "Max Depth (Layers)"),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
                                TextButton(
                                  onPressed: () async {
                                    int? depth = int.tryParse(_depthController.text);
                                    if (depth != null && depth >= 0) {
                                      var updatedLib = MusicLibrary(
                                        id: lib.id,
                                        name: lib.name,
                                        remotePath: lib.remotePath,
                                        serverUrl: lib.serverUrl,
                                        userId: lib.userId,
                                        createTime: lib.createTime,
                                        maxDepth: depth,
                                      );
                                      await _dbController.musicLibraryDao.updateLibrary(updatedLib);
                                      Navigator.pop(context);
                                      _loadLibraries();
                                      _scannerService.scanLibrary(updatedLib);
                                      SmartDialog.showToast("Depth updated to $depth. Scanning...");
                                    }
                                  },
                                  child: const Text("SAVE"),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
