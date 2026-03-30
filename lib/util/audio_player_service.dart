import 'dart:async';
import 'dart:math';
import 'dart:io' as io;

import 'package:alist/database/alist_database_controller.dart';
import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/util/file_utils.dart';
import 'package:alist/util/lock_caching_audio_source.dart';
import 'package:alist/util/user_controller.dart';
import 'package:dio/dio.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

enum PlayMode {
  single,
  list,
  random,
}

class AudioItem {
  final String name;
  String? localPath;
  final String remotePath;
  final String? sign;
  final String? provider;

  AudioItem({
    required this.name,
    this.localPath,
    required this.remotePath,
    this.sign,
    this.provider,
  });
}

class AudioPlayerService extends GetxService {
  static AudioPlayerService get instance => Get.find<AudioPlayerService>();

  final _audioPlayer = AudioPlayer();
  final CancelToken _cancelToken = CancelToken();
  late ConcatenatingAudioSource _playList;

  final RxList<AudioItem> audios = <AudioItem>[].obs;
  final RxInt currentIndex = (-1).obs;
  final playMode = PlayMode.list.obs;
  final name = "".obs;

  final duration = const Duration().obs;
  final currentPos = const Duration().obs;

  final playing = false.obs;
  final prepared = false.obs;
  final seekPos = (-1.0).obs;

  List<StreamSubscription> streamSubscriptions = [];

  AudioPlayer get player => _audioPlayer;

  @override
  void onInit() {
    super.onInit();
    
    streamSubscriptions.add(_audioPlayer.durationStream.listen((event) {
      if (event != null) duration.value = event;
    }));

    streamSubscriptions.add(_audioPlayer.positionStream.listen((event) {
      currentPos.value = event;
      if (duration.value.inMilliseconds < currentPos.value.inMilliseconds) {
        currentPos.value = duration.value;
      }
    }));

    streamSubscriptions.add(_audioPlayer.sequenceStateStream.listen((event) {
      if (event != null && audios.isNotEmpty) {
        currentIndex.value = event.currentIndex;
        var item = event.currentSource?.tag as MediaItem?;
        if (item?.id == audios[currentIndex.value].remotePath) {
          name.value = audios[currentIndex.value].name;
        }
      }
    }));

    streamSubscriptions.add(_audioPlayer.playerStateStream.listen((state) {
      if (state.playing) {
        prepared.value = true;
        playing.value = true;
      } else {
        playing.value = false;
      }
      if (state.processingState == ProcessingState.completed) {
        playNext();
      }
    }));
  }

  Future<void> playNewList(List<AudioItem> newAudios, int index) async {
    if (newAudios.isEmpty) return;

    // Avoid reloading if playing the exact same list
    if (audios.length == newAudios.length && currentIndex.value == index) {
      bool same = true;
      for (int i = 0; i < audios.length; i++) {
        if (audios[i].remotePath != newAudios[i].remotePath) {
          same = false;
          break;
        }
      }
      if (same) {
        if (!playing.value) {
          _audioPlayer.play();
        }
        return;
      }
    }

    // Load new list
    prepared.value = false;
    currentPos.value = const Duration(milliseconds: 0);
    duration.value = const Duration(milliseconds: 0);
    seekPos.value = -1.0;
    
    audios.value = newAudios;
    if (index < 0 || index >= audios.length) index = 0;
    currentIndex.value = index;
    name.value = audios[index].name;

    var sources = <AudioSource>[];
    for (var audio in audios) {
      var uri = await FileUtils.makeFileLink(audio.remotePath, audio.sign);
      if (uri != null) {
        sources.add(await _audioToUri(uri, audio));
      }
    }

    _playList = ConcatenatingAudioSource(
      useLazyPreparation: true,
      shuffleOrder: DefaultShuffleOrder(),
      children: sources,
    );
    await _audioPlayer.setAudioSource(_playList, initialIndex: currentIndex.value);
    _audioPlayer.play();
  }

  Future<AudioSource> _audioToUri(String uri, AudioItem audio) async {
    final mediaItem = MediaItem(
      id: audio.remotePath,
      title: audio.name,
      artUri: Uri.parse("https://alistc.techyifu.com/ic_music_head.png"),
    );

    if (audio.localPath == null || audio.localPath!.isEmpty) {
      AlistDatabaseController databaseController = Get.find();
      UserController userController = Get.find();
      var user = userController.user.value;

      var record = await databaseController.downloadRecordRecordDao
          .findRecordByRemotePath(user.serverUrl, user.username, audio.remotePath);
      if (record != null && io.File(record.localPath).existsSync()) {
        audio.localPath = record.localPath;
      }
    }
    
    if (audio.localPath != null && audio.localPath!.isNotEmpty) {
      return ProgressiveAudioSource(Uri.file(audio.localPath!), tag: mediaItem);
    } else {
      if (GetPlatform.isDesktop) {
        return ProgressiveAudioSource(Uri.parse(uri), tag: mediaItem);
      } else {
        var headers = <String, String>{};
        if (audio.provider == "BaiduNetdisk") {
          headers["User-Agent"] = "pan.baidu.com";
        }
        return AlistLockCachingAudioSource(
          Uri.parse(uri),
          headers: headers,
          tag: mediaItem,
        );
      }
    }
  }

  void playNext() {
    currentPos.value = const Duration(milliseconds: 0);
    if (_audioPlayer.hasNext) {
      _audioPlayer.seekToNext();
    } else {
      var nextIndex = 0;
      if (playMode.value == PlayMode.random) {
        nextIndex = Random().nextInt(audios.length);
      }
      _audioPlayer.seek(const Duration(milliseconds: 0), index: nextIndex);
    }
    if (!_audioPlayer.playing) _audioPlayer.play();
  }

  void playPrevious() {
    currentPos.value = const Duration(milliseconds: 0);
    if (_audioPlayer.hasPrevious) {
      _audioPlayer.seekToPrevious();
    } else {
      var previousIndex = 0;
      if (playMode.value == PlayMode.random) {
        previousIndex = Random().nextInt(audios.length);
      }
      _audioPlayer.seek(const Duration(milliseconds: 0), index: previousIndex);
    }
    if (!_audioPlayer.playing) _audioPlayer.play();
  }

  void playOrPause() async {
    if (playing.value == true) {
      await _audioPlayer.pause();
    } else {
      if (duration.value.inMilliseconds <= currentPos.value.inMilliseconds) {
        await _audioPlayer.seek(const Duration(milliseconds: 0));
        await _audioPlayer.play();
      } else {
        await _audioPlayer.play();
      }
    }
  }

  void play(int index) {
    currentIndex.value = index;
    currentPos.value = const Duration(milliseconds: 0);
    _audioPlayer.seek(Duration.zero, index: index);
  }

  void remove(int index) {
    if (audios.length <= 1) {
      SmartDialog.showToast(Intl.audioPlayListDialog_tips_deleteTheLast.tr);
      return;
    }
    if (currentIndex.value == index) {
      playNext();
    }
    _playList.removeAt(index);
    audios.removeAt(index);
  }

  void changePlayMode() {
    if (playMode.value == PlayMode.single) {
      playMode.value = PlayMode.list;
      SmartDialog.showToast(Intl.audioPlayerScreen_btn_sequence.tr);
      _audioPlayer.setLoopMode(LoopMode.all);
      _audioPlayer.setShuffleModeEnabled(false);
    } else if (playMode.value == PlayMode.list) {
      playMode.value = PlayMode.random;
      SmartDialog.showToast(Intl.audioPlayerScreen_btn_shuffle.tr);
      _audioPlayer.setLoopMode(LoopMode.all);
      _audioPlayer.setShuffleModeEnabled(true);
    } else if (playMode.value == PlayMode.random) {
      playMode.value = PlayMode.single;
      _audioPlayer.setLoopMode(LoopMode.one);
      SmartDialog.showToast(Intl.audioPlayerScreen_btn_repeatOne.tr);
    }
  }

  void stopAndClear() async {
    await _audioPlayer.stop();
    audios.clear();
    prepared.value = false;
    name.value = "";
  }

  @override
  void onClose() {
    _cancelToken.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    for (var element in streamSubscriptions) {
      element.cancel();
    }
    streamSubscriptions.clear();
    super.onClose();
  }
}
