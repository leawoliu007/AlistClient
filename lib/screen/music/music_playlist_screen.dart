import 'package:alist/database/alist_database_controller.dart';
import 'package:alist/database/table/music_library.dart';
import 'package:alist/database/table/music_track.dart';
import 'package:alist/screen/audio_player_screen.dart';
import 'package:alist/util/audio_player_service.dart';
import 'package:alist/util/music_scanner_service.dart';
import 'package:alist/util/named_router.dart';
import 'package:alist/widget/alist_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MusicPlaylistScreen extends StatefulWidget {
  final MusicLibrary library;

  const MusicPlaylistScreen({Key? key, required this.library}) : super(key: key);

  @override
  State<MusicPlaylistScreen> createState() => _MusicPlaylistScreenState();
}

class _MusicPlaylistScreenState extends State<MusicPlaylistScreen> {
  final AlistDatabaseController _dbController = Get.find();
  final MusicScannerService _scannerService = MusicScannerService.instance;

  List<MusicTrack> _tracks = [];

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final tracks = await _dbController.musicTrackDao.findTracksByLibraryId(widget.library.id!);
    if (mounted) {
      setState(() {
        _tracks = tracks;
      });
    }
  }

  void _playAll(int startIndex) {
    if (_tracks.isEmpty) return;

    List<AudioItem> audioItems = _tracks.map((t) => AudioItem(
      name: t.name,
      remotePath: t.remotePath,
      sign: t.sign,
      provider: t.provider,
    )).toList();

    Get.toNamed(
      NamedRouter.audioPlayer,
      arguments: {"audios": audioItems, "index": startIndex},
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlistScaffold(
      showLeading: true,
      appbarTitle: Text(widget.library.name),
      appbarActions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            _scannerService.scanLibrary(widget.library).then((_) => _loadTracks());
          },
        )
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text("${_tracks.length} tracks found", style: Theme.of(context).textTheme.titleMedium),
                ),
                ElevatedButton.icon(
                  onPressed: _tracks.isEmpty ? null : () => _playAll(0),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("PLAY ALL"),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _tracks.isEmpty
                ? const Center(child: Text("No tracks found or scan in progress."))
                : ListView.builder(
                    itemCount: _tracks.length,
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
                      return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(track.remotePath, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                        onTap: () => _playAll(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
