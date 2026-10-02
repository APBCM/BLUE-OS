import 'package:blue_system/blue_system.dart';
import 'package:flutter/foundation.dart';
import 'catalog.dart';

class StoreModel extends ChangeNotifier {
  StoreModel(this.packages, {Future<List<CatalogApp>> Function()? loader}) : loader = loader ?? loadCatalog;
  final PackageService packages;
  final Future<List<CatalogApp>> Function() loader;
  List<CatalogApp> apps = [];
  final installed = <String, bool>{};
  bool busy = false;
  bool flatpakAvailable = true;
  String? error;

  Future<void> initialize() async {
    try {
      apps = await loader();
      flatpakAvailable = await packages.runner.hasFlatpak;
      notifyListeners();
      for (final app in apps) {
        installed[app.id] = app.type == 'apt'
            ? await packages.aptInstalled(app.package)
            : flatpakAvailable && await packages.flatpakInstalled(app.package);
        notifyListeners();
      }
    } catch (exception) { error = exception.toString(); notifyListeners(); }
  }

  Future<void> change(CatalogApp app) async {
    if (busy) return;
    busy = true; error = null; notifyListeners();
    try {
      final remove = installed[app.id] ?? false;
      final result = app.type == 'apt'
          ? (remove ? await packages.aptRemove(app.package) : await packages.aptInstall(app.package))
          : (remove ? await packages.flatpakRemove(app.package) : await packages.flatpakInstall(app.remote, app.package));
      if (!result.ok) throw Exception(result.stderr.isEmpty ? 'Operation failed (${result.exitCode})' : result.stderr);
      installed[app.id] = !remove;
    } catch (exception) { error = exception.toString(); }
    busy = false; notifyListeners();
  }

  Future<void> installFlatpak() async {
    if (busy) return;
    busy = true; notifyListeners();
    try {
      final result = await packages.aptInstall('flatpak');
      if (!result.ok) throw Exception(result.stderr);
      flatpakAvailable = true; error = null;
    } catch (exception) { error = exception.toString(); }
    busy = false; notifyListeners();
  }
}
