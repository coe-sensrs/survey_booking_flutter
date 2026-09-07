import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/routing/app_router.dart';
import 'core/services/firebase_app_check_setup.dart';
import 'core/services/hive_storage_service.dart';
import 'core/utils/app_snackbar.dart';
import 'features/auth/viewmodel/auth_viewmodel.dart';

void main() async {
  WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await HiveStorageService.init();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheckSetup.initialize();

  // Set crashlytics collection enabled only in release mode
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode,
  );

  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const ProviderScope(child: SurveyDeskApp()));

  // NOTE: FlutterNativeSplash.remove() is called by AsyncAuthNotifier
  // (in app_router.dart) once auth + Firestore role resolution completes.
  // This keeps the native splash visible until GoRouter knows the correct
  // destination, so users never see a flash of the wrong screen.
}

class SurveyDeskApp extends ConsumerStatefulWidget {
  const SurveyDeskApp({super.key});

  @override
  ConsumerState<SurveyDeskApp> createState() => _SurveyDeskAppState();
}

class _SurveyDeskAppState extends ConsumerState<SurveyDeskApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _onAppResumed);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// Proactively validate that the Firebase session is still valid
  /// (e.g. password wasn't reset on another device, account wasn't disabled).
  void _onAppResumed() {
    ref.read(authViewModelProvider.notifier).validateCurrentSession();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return ScreenUtilPlusInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      autoRebuild: false,
      builder: (context, child) {
        return MaterialApp.router(
          scaffoldMessengerKey: AppSnackbar.scaffoldMessengerKey,
          title: 'Survey Desk',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
