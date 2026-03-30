import 'dart:math';
import 'dart:ui';

import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/util/audio_player_service.dart';
import 'package:alist/widget/alist_scaffold.dart';
import 'package:alist/widget/slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class AudioPlayerScreen extends StatefulWidget {
  AudioPlayerScreen({Key? key}) : super(key: key);

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final AudioPlayerService controller = AudioPlayerService.instance;

  @override
  void initState() {
    super.initState();
    final List<AudioItem> audios = Get.arguments?["audios"] ?? [];
    final int index = Get.arguments?["index"] ?? 0;
    if (audios.isNotEmpty) {
      controller.playNewList(audios, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlistScaffold(
      appbarTitle: const SizedBox(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 30, right: 30, bottom: 10),
              child: Obx(() => Text(controller.name.value)),
            ),
            Container(
              width: double.infinity,
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Obx(() => _buildFijkSlider(controller)),
            ),
            _buildButtons(controller, context),
          ],
        ),
      ),
    );
  }

  Row _buildButtons(
      AudioPlayerService controller, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(5.0),
          child: IconButton(
            iconSize: 40,
            icon: Obx(() {
              if (controller.playMode.value == PlayMode.list) {
                return const Icon(Icons.repeat);
              } else if (controller.playMode.value == PlayMode.single) {
                return const Icon(Icons.repeat_one);
              } else {
                return const Icon(Icons.shuffle);
              }
            }),
            onPressed: () {
              controller.changePlayMode();
            },
          ),
        ),
        Obx(() => IconButton(
              iconSize: 50,
              icon: const Icon(Icons.skip_previous),
              onPressed: controller.playMode.value == PlayMode.single ||
                      controller.audios.length <= 1
                  ? null
                  : () {
                      controller.playPrevious();
                    },
            )),
        Obx(
          () => _PlayButton(
            playing: controller.playing.value,
            onPressed: controller.playOrPause,
          ),
        ),
        Obx(() => IconButton(
              iconSize: 50,
              icon: const Icon(Icons.skip_next),
              onPressed: controller.playMode.value == PlayMode.single ||
                      controller.audios.length <= 1
                  ? null
                  : () {
                      controller.playNext();
                    },
            )),
        IconButton(
          iconSize: 50,
          icon: const Icon(Icons.playlist_play_rounded),
          onPressed: () {
            _showPlayerList(context, controller);
          },
        ),
      ],
    );
  }

  Widget _buildFijkSlider(AudioPlayerService controller) {
    if (!controller.prepared.value) {
      return const SizedBox();
    }

    double duration = controller.duration.value.inMilliseconds.toDouble();
    double currentValue = controller.seekPos.value > 0
        ? controller.seekPos.value
        : controller.currentPos.value.inMilliseconds.toDouble();
    Widget slider = FijkSlider(
      value: currentValue,
      cacheValue: currentValue,
      min: 0.0,
      max: max(duration, 1),
      onChanged: (v) {
        controller.seekPos.value = v;
      },
      onChangeEnd: (v) {
        controller.currentPos.value = Duration(milliseconds: v.toInt());
        controller.player.seek(controller.currentPos.value);
        controller.seekPos.value = -1;
      },
    );
    return Row(
      children: [
        Text(
          _duration2String(controller.seekPos.value > 0
              ? Duration(milliseconds: controller.seekPos.value.toInt())
              : controller.currentPos.value),
          style: const TextStyle(
            fontSize: 12,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Expanded(
            child: Padding(
          padding: const EdgeInsets.only(left: 7.5, right: 10),
          child: slider,
        )),
        Text(
          _duration2String(controller.duration.value),
          style: const TextStyle(
            fontSize: 12,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        )
      ],
    );
  }

  String _duration2String(Duration duration) {
    if (duration.inMilliseconds < 0) return "-: negtive";

    String twoDigits(int n) {
      if (n >= 10) return "$n";
      return "0$n";
    }

    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    int inHours = duration.inHours;
    return inHours > 0
        ? "$inHours:$twoDigitMinutes:$twoDigitSeconds"
        : "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showPlayerList(
      BuildContext context, AudioPlayerService controller) {
    if (controller.audios.isEmpty) return;
    var scrollController = AutoScrollController();
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  "${Intl.audioPlayListDialog_title.tr}(${controller.audios.length})",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                  child: Obx(() => _playList(scrollController, controller))),
            ],
          );
        });

    Future.delayed(const Duration(milliseconds: 200)).then((value) {
      scrollController.scrollToIndex(controller.currentIndex.value,
          duration: const Duration(milliseconds: 50),
          preferPosition: AutoScrollPosition.begin);
    });
  }

  ListView _playList(AutoScrollController scrollController,
      AudioPlayerService controller) {
    return ListView.separated(
      controller: scrollController,
      itemBuilder: (context, index) {
        return _buildPlayListItem(scrollController, controller, context, index);
      },
      separatorBuilder: (context, index) => const Divider(),
      itemCount: controller.audios.length,
    );
  }

  Widget _buildPlayListItem(AutoScrollController scrollController,
      AudioPlayerService controller, BuildContext context, int index) {
    var isPlayingIndex = controller.currentIndex.value == index;
    return AutoScrollTag(
      key: ValueKey(controller.audios[index]),
      controller: scrollController,
      index: index,
      child: ListTile(
        title: Text(controller.audios[index].name,
            style: isPlayingIndex
                ? TextStyle(color: Theme.of(context).colorScheme.primary)
                : const TextStyle()),
        onTap: () {
          Navigator.pop(context);
          if (controller.currentIndex.value == index) {
            controller.playOrPause();
          } else {
            controller.play(index);
          }
        },
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            controller.remove(index);
          },
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({Key? key, required this.playing, required this.onPressed})
      : super(key: key);
  final VoidCallback onPressed;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 50,
      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      padding: const EdgeInsets.only(left: 10.0, right: 10.0),
      onPressed: onPressed,
    );
  }
}
