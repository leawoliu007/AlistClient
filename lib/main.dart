import 'package:alist/l10n/alist_translations.dart';
import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/router.dart';
import 'package:alist/util/log_utils.dart';
import 'package:alist/util/named_router.dart';
import 'package:alist/util/proxy.dart';
import 'package:alist/util/user_controller.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'database/alist_database_controller.dart';
import 'generated/color_schemes.g.dart';
import 'package:alist/net/dio_utils.dart';
import 'package:alist/util/constant.dart';
import 'package:alist/util/global.dart';
import 'package:alist/util/audio_player_service.dart';
import 'package:alist/util/music_scanner_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // sp初始化
  await SpUtil.getInstance();
  
  // 从编译环境读取 DEVICE_MODE (--dart-define=DEVICE_MODE=tv/car)
  const String deviceMode = String.fromEnvironment('DEVICE_MODE', defaultValue: 'phone');
  bool defaultCarMode = (deviceMode == 'car');
  bool defaultTvMode = (deviceMode == 'tv');
  
  Global.isCarMode.value = SpUtil.getBool(AlistConstant.isCarMode, defValue: defaultCarMode) ?? defaultCarMode;
  Global.isTvMode.value = SpUtil.getBool(AlistConstant.isTvMode, defValue: defaultTvMode) ?? defaultTvMode;
  Log.init();
  await DioUtils.initCronet();
  runApp(const MyApp());
}

class _BackIntent extends Intent {
  const _BackIntent();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialRoute: NamedRouter.root,
      translations: AlistTranslations(),
      fallbackLocale: const Locale('en', 'US'),
      locale: PlatformDispatcher.instance.locale,
      getPages: AlistRouter.screens,
      builder: _routerBuilder,
      navigatorObservers: [FlutterSmartDialog.observer],
      defaultTransition: Transition.cupertino,
      title: "ALClient",
      theme: _lightTheme(context),
      darkTheme: _dartTheme(context),
    );
  }



  Widget _routerBuilder(BuildContext context, Widget? widget) {
    final smartDialogInit = FlutterSmartDialog.init();
    Get.put(AlistDatabaseController());
    Get.put(UserController());
    Get.put(ProxyServer());
    Get.put(AudioPlayerService(), permanent: true);
    Get.put(MusicScannerService(), permanent: true);

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const _BackIntent(),
        LogicalKeySet(LogicalKeyboardKey.goBack): const _BackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _BackIntent: CallbackAction<_BackIntent>(
            onInvoke: (intent) async {
              await WidgetsBinding.instance.handlePopRoute();
              return null;
            },
          ),
        },
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1),
          child: RefreshConfiguration(
              headerBuilder: () {
                return ClassicHeader(
                  idleText: Intl.pullRefresh_idleRefreshText.tr,
                  releaseText: Intl.pullRefresh_canRefreshText.tr,
                  refreshingText: Intl.pullRefresh_refreshingText.tr,
                  completeText: Intl.pullRefresh_refreshCompleteText.tr,
                  failedText: Intl.pullRefresh_refreshFailedText.tr,
                );
              },
              child: smartDialogInit(context, widget)),
        ),
      ),
    );
  }

  ThemeData _dartTheme(BuildContext context) {
    return ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        focusColor: Global.isTvMode.value ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.15),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1E1E1E),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        dividerTheme: DividerTheme.of(context).copyWith(
          thickness: 0,
          space: 0,
          color: Colors.white.withOpacity(0.05),
        ),
        appBarTheme: AppBarTheme.of(context).copyWith(
          backgroundColor: const Color(0xFF121212).withOpacity(0.95),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF121212),
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        ));
  }

  ThemeData _lightTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      hintColor: const Color(0xFFBBBBBB),
      colorScheme: lightColorScheme,
      focusColor: Global.isTvMode.value ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.12),
      scaffoldBackgroundColor: const Color(0xFFF7F7F9),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: DividerTheme.of(context).copyWith(
        thickness: 0,
        space: 0,
        color: Colors.black.withOpacity(0.05),
      ),
      appBarTheme: AppBarTheme.of(context).copyWith(
        backgroundColor: const Color(0xFFF7F7F9).withOpacity(0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFFF7F7F9),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
    );
  }
}
