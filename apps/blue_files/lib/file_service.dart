import 'dart:io';
import 'package:blue_system/blue_system.dart';

class FileItem {
  const FileItem(this.entity, this.size, this.modified);
  final FileSystemEntity entity;
  final int size;
  final DateTime modified;
  bool get directory => entity is Directory;
  String get name => entity.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
}

class FileService {
  FileService(this.runner);
  final SystemRunner runner;

  Future<List<FileItem>> list(String path) async {
    final items = <FileItem>[];
    await for (final entity in Directory(path).list(followLinks: false)) {
      final stat = await entity.stat();
      items.add(FileItem(entity, stat.size, stat.modified));
    }
    return items;
  }

  Future<void> open(FileSystemEntity entity) async {
    if (entity is Directory) return;
    final result = await runner.runCommand('xdg-open', [entity.path]);
    if (!result.ok) throw FileSystemException(result.stderr, entity.path);
  }

  Future<void> rename(FileSystemEntity entity, String newName) async {
    validateName(newName);
    final target = '${entity.parent.path}/$newName';
    if (await FileSystemEntity.type(target, followLinks: false) != FileSystemEntityType.notFound) {
      throw FileSystemException('A file already has that name', target);
    }
    await entity.rename(target);
  }

  Future<void> newFolder(String parent, String name) async {
    validateName(name);
    await Directory('$parent/$name').create();
  }

  Future<void> copy(FileSystemEntity source, String destination) async {
    final name = source.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
    final target = '$destination/$name';
    if (await FileSystemEntity.type(target, followLinks: false) != FileSystemEntityType.notFound) {
      throw FileSystemException('Destination already exists', target);
    }
    if (source is File) { await source.copy(target); return; }
    if (source is Link) { await Link(target).create(await source.target()); return; }
    if (source is Directory) {
      final canonicalSource = await source.resolveSymbolicLinks();
      final canonicalDestination = await Directory(destination).resolveSymbolicLinks();
      if (canonicalDestination == canonicalSource || canonicalDestination.startsWith('$canonicalSource/')) {
        throw FileSystemException('Cannot copy a directory into itself', destination);
      }
      await Directory(target).create();
      await for (final child in source.list(followLinks: false)) { await copy(child, target); }
    }
  }

  Future<void> move(FileSystemEntity source, String destination) async {
    await copy(source, destination);
    await deletePermanently(source);
  }

  Future<void> trash(FileSystemEntity entity) async {
    final result = await runner.runCommand('gio', ['trash', entity.absolute.path]);
    if (!result.ok) throw FileSystemException(result.stderr, entity.path);
  }

  Future<void> deletePermanently(FileSystemEntity entity) async {
    if (entity is Directory) { await entity.delete(recursive: true); }
    else { await entity.delete(); }
  }

  static void validateName(String name) {
    if (name.isEmpty || name == '.' || name == '..' || name.contains('/') || name.contains('\u0000')) {
      throw const FormatException('Invalid file name');
    }
  }
}
