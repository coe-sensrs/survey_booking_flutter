import 'package:hive_flutter/hive_flutter.dart';

/// Centralized Hive local storage service.
///
/// Initialize once in `main()` before `runApp()`:
/// ```dart
/// await HiveStorageService.init();
/// ```
class HiveStorageService {
  HiveStorageService._();

  // -- Box Names ------------------------------------------------------------
  static const _settingsBox = 'settingsBox';
  static const _wizardDraftBox = 'wizard_draft_box';
  static const _cacheBox = 'cacheBox';

  // -- Keys -----------------------------------------------------------------
  static const _keyThemeMode = 'themeMode';
  static const _keyWizardDraft = 'draft';

  // -- Initialization --------------------------------------------------------

  /// Must be called once in `main()` before `runApp()`.
  /// Opens all boxes in parallel so they are available synchronously
  /// everywhere in the app.
  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(_settingsBox),
      Hive.openBox(_wizardDraftBox),
      Hive.openBox(_cacheBox),
    ]);
  }

  // -- Settings: Theme -------------------------------------------------------

  /// Returns the persisted theme mode string: `'light'`, `'dark'`, or `'system'`.
  static String getThemeMode() =>
      Hive.box(_settingsBox).get(_keyThemeMode, defaultValue: 'system')
          as String;

  /// Persists [mode]: `'light'`, `'dark'`, or `'system'`.
  static Future<void> setThemeMode(String mode) =>
      Hive.box(_settingsBox).put(_keyThemeMode, mode);

  // -- Booking Wizard Draft --------------------------------------------------

  /// Returns the JSON-encoded wizard draft, or `null` if none exists.
  static String? getWizardDraft() =>
      Hive.box(_wizardDraftBox).get(_keyWizardDraft) as String?;

  /// Persists the wizard draft as a JSON string.
  static Future<void> saveWizardDraft(String json) =>
      Hive.box(_wizardDraftBox).put(_keyWizardDraft, json);

  /// Deletes the persisted wizard draft.
  static Future<void> clearWizardDraft() =>
      Hive.box(_wizardDraftBox).delete(_keyWizardDraft);

  // -- Generic Offline Cache -------------------------------------------------
  // Use these for caching profile data, appointments, feed, etc.

  /// Stores [value] under [key] in the generic cache box.
  static Future<void> cacheData(String key, dynamic value) =>
      Hive.box(_cacheBox).put(key, value);

  /// Returns the cached value for [key], or `null` if not found.
  static T? getCachedData<T>(String key) => Hive.box(_cacheBox).get(key) as T?;

  /// Returns true if the cache contains [key].
  static bool isCached(String key) => Hive.box(_cacheBox).containsKey(key);

  /// Removes a single key from the cache.
  static Future<void> evict(String key) => Hive.box(_cacheBox).delete(key);

  /// Clears all entries from the generic cache (e.g., on logout).
  static Future<void> clearCache() => Hive.box(_cacheBox).clear();

  // -- Global Reset ----------------------------------------------------------

  /// Wipes ALL user-generated local storage (use on full sign-out or account reset).
  /// Theme preference is intentionally preserved.
  static Future<void> clearUserData() async {
    await Future.wait([
      Hive.box(_wizardDraftBox).clear(),
      Hive.box(_cacheBox).clear(),
    ]);
  }
}
