import 'package:blue_system/blue_system.dart';
import 'package:flutter/foundation.dart';
import 'catalog.dart';

class StoreModel extends ChangeNotifier {
  StoreModel(this.packages, {Future<List<CatalogApp>> Function()? loader}) : loader = loader ?? loadCatalog;
  final PackageService packages;
  final Future<List<CatalogApp>> Function() loader;
  List<CatalogApp> apps = [];
  List<CatalogApp> remoteResults = [];
  String? selectedCategory;
  final installed = <String, bool>{};
  bool busy = false;
  String? activeAppId;
  bool flatpakAvailable = true;
  String? error;

  void setCategory(String? category) {
    selectedCategory = category;
    notifyListeners();
  }

  Future<void> searchFlathub(String query) async {
    if (busy || !flatpakAvailable) return;
    busy = true; error = null; remoteResults = []; notifyListeners();
    try {
      final results = await packages.flatpakSearch(query);
      remoteResults = results.map((item) => CatalogApp(
        id: 'flathub:${item.id}', nameFa: item.name, nameEn: item.name,
        summaryFa: item.description, summaryEn: item.description,
        type: 'flatpak', package: item.id, remote: 'flathub', category: 'tools', popular: false,
      )).toList();
      for (final app in remoteResults) {
        installed[app.id] = await packages.flatpakInstalled(app.package);
      }
    } catch (exception) { error = exception.toString(); }
    busy = false; notifyListeners();
  }

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
    busy = true; activeAppId = app.id; error = null; notifyListeners();
    try {
      final remove = installed[app.id] ?? false;
      final result = app.type == 'apt'
          ? (remove ? await packages.aptRemove(app.package) : await packages.aptInstall(app.package))
          : (remove ? await packages.flatpakRemove(app.package) : await packages.flatpakInstall(app.remote, app.package));
      if (!result.ok) throw Exception(result.stderr.isEmpty ? 'Operation failed (${result.exitCode})' : result.stderr);
      installed[app.id] = !remove;
    } catch (exception) { error = exception.toString(); }
    busy = false; activeAppId = null; notifyListeners();
  }

  Future<void> launch(CatalogApp app) async {
    if (app.type != 'flatpak' || !(installed[app.id] ?? false)) return;
    final result = await packages.launchFlatpak(app.package);
    if (!result.ok) {
      error = result.stderr.isEmpty ? 'Unable to launch ${app.nameEn}' : result.stderr;
      notifyListeners();
    }
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
