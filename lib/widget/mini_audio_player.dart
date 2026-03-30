import 'package:alist/util/audio_player_service.dart';
import 'package:alist/util/named_router.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MiniAudioPlayer extends StatelessWidget {
  const MiniAudioPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AudioPlayerService>()) {
      return const SizedBox.shrink();
    }
    final AudioPlayerService controller = AudioPlayerService.instance;

    return Obx(() {
      if (controller.audios.isEmpty) {
        return const SizedBox.shrink();
      }

      var isDarkMode = Theme.of(context).brightness == Brightness.dark;
      var bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
      var shadowColor = isDarkMode ? Colors.black54 : Colors.black12;

      return GestureDetector(
        onTap: () {
          Get.toNamed(NamedRouter.audioPlayer);
        },
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.name.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 32,
                icon: Icon(
                  controller.playing.value ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: controller.playOrPause,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 24),
                color: Theme.of(context).hintColor,
                onPressed: controller.stopAndClear,
              ),
            ],
          ),
        ),
      );
    });
  }
}
