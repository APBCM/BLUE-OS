import 'dart:io';
import 'package:flutter/foundation.dart';
import 'file_service.dart';

enum FileSort { name, date, size }

class FilesModel extends ChangeNotifier {
  FilesModel(this.service, {String? initialPath}) : path = initialPath ?? Platform.environment['HOME'] ?? '/home';
  final FileService service;
  String path;
  List<FileItem> items = [];
  FileSort sort = FileSort.name;
  FileSystemEntity? clipboard;
  bool cut = false;
  bool busy = false;
  String? error;

  Future<void> load([String? location]) async {
    busy = true; error = null; notifyListeners();
    try {
      final next = location ?? path;
      final listing = await service.list(next);
      path = next; items = listing; _sort();
    } catch (exception) { error = _message(exception); }
    busy = false; notifyListeners();
  }

  void sortBy(FileSort value) { sort = value; _sort(); notifyListeners(); }
  void _sort() {
    items.sort((first, second) {
      if (first.directory != second.directory) return first.directory ? -1 : 1;
      switch (sort) {
        case FileSort.name: return first.name.toLowerCase().compareTo(second.name.toLowerCase());
        case FileSort.date: return second.modified.compareTo(first.modified);
        case FileSort.size: return second.size.compareTo(first.size);
      }
    });
  }

  void select(FileSystemEntity entity, {required bool move}) {
    clipboard = entity; cut = move; notifyListeners();
  }

  Future<void> paste() async {
    final source = clipboard;
    if (source == null) return;
    await perform(() => cut ? service.move(source, path) : service.copy(source, path));
    if (error == null && cut) { clipboard = null; cut = false; notifyListeners(); }
  }

  Future<void> perform(Future<void> Function() operation) async {
    busy = true; error = null; notifyListeners();
    try { await operation(); await load(); }
    catch (exception) { error = _message(exception); busy = false; notifyListeners(); }
  }

  String _message(Object exception) {
    if (exception is FileSystemException) {
      if (exception.osError?.errorCode == 13) return 'دسترسی مجاز نیست / Permission denied: ${exception.path ?? path}';
      if (exception.osError?.errorCode == 2) return 'پرونده پیدا نشد / File not found: ${exception.path ?? path}';
    }
    return 'عملیات ناموفق بود / Operation failed: $exception';
  }
}
