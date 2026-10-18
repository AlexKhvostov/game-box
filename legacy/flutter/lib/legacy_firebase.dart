// Explicit opt-in for the archived target; never imported by the Android app.
import 'package:game_box/data/app_analytics.dart' as facade;
import 'data/firebase_analytics_adapter.dart' as native;
import 'data/firebase_bootstrap.dart';
export 'data/firestore_scores_source.dart';
Future<bool> initializeLegacyFirebase() async {
  if (!await FirebaseBootstrap.init()) return false;
  await native.AppAnalytics.init();
  facade.AppAnalytics.sink = (name, params) => native.AppAnalytics.log(name, params: params);
  return true;
}
