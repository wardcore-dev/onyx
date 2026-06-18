import '../utils/onyx_base_dir.dart';
import 'app_database.dart';

/// Singleton holder for the Drift AppDatabase.
/// Call [DbProvider.init] once at app startup (after OnyxBaseDir is ready),
/// then use [DbProvider.db] everywhere.
class DbProvider {
  DbProvider._();

  static AppDatabase? _instance;

  static AppDatabase get db {
    assert(_instance != null, 'DbProvider.init() must be called before db');
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  static Future<void> init() async {
    if (_instance != null) return;
    final dir = await getOnyxSupportDirectory();
    _instance = AppDatabase(dir.path);
    // Warm up the connection so the first query is fast.
    await _instance!.customSelect('SELECT 1').get();
  }

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}
