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

  void _addLibraryDialog() {
    final TextEditingController _pathController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Music Library"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter the remote path on your Alist server that contains your music (e.g., /MyMusic):"),
              const SizedBox(height: 10),
              TextField(
                controller: _pathController,
                decoration: const InputDecoration(
                  labelText: "Remote Path",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              onPressed: () async {
                String path = _pathController.text.trim();
                if (path.isEmpty || !path.startsWith('/')) {
                  SmartDialog.showToast("Path must start with '/'");
                  return;
                }
                
                final user = _userController.user.value;
                
                // check if already exists
                var existing = await _dbController.musicLibraryDao.findByPath(user.serverUrl, user.username, path);
                if (existing != null) {
                  SmartDialog.showToast("Library already exists");
                  Navigator.pop(context);
                  return;
                }
                
                String name = path.split('/').last;
                if (name.isEmpty) name = "Root Music";

                var newLib = MusicLibrary(
                  name: name,
                  remotePath: path,
                  serverUrl: user.serverUrl,
                  userId: user.username,
                  createTime: DateTime.now().millisecondsSinceEpoch,
                );
                
                int id = await _dbController.musicLibraryDao.insertLibrary(newLib);
                newLib = MusicLibrary(
                  id: id,
                  name: name,
                  remotePath: path,
                  serverUrl: user.serverUrl,
                  userId: user.username,
                  createTime: newLib.createTime,
                );
                
                Navigator.pop(context);
                await _loadLibraries();
                _scannerService.scanLibrary(newLib);
              },
              child: const Text("ADD & SCAN"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlistScaffold(
      appbarTitle: const Text("Music Library"),
      appbarActions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _addLibraryDialog,
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
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await _dbController.musicTrackDao.deleteTracksByLibraryId(lib.id!);
                            await _dbController.musicLibraryDao.deleteById(lib.id!);
                            _loadLibraries();
                          },
                        ),
                        onTap: () {
                          Get.to(() => MusicPlaylistScreen(library: lib));
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
