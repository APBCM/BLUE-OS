library blue_system;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class CommandResult {
  const CommandResult(this.exitCode, this.stdout, this.stderr);
  final int exitCode;
  final String stdout;
  final String stderr;
  bool get ok => exitCode == 0;
}

class FlatpakSearchResult {
  const FlatpakSearchResult(this.id, this.name, this.description);
  final String id;
  final String name;
  final String description;
}

class PackageIds {
  static final apt = RegExp(r'^[a-z0-9][a-z0-9+.-]+$');
  static final flatpak = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)?$');
  static bool validApt(String value) => apt.hasMatch(value);
  static bool validFlatpak(String value) => flatpak.hasMatch(value) &&
      value.split('/').every((part) => part != '.' && part != '..');
}

class SystemRunner {
  final _logs = StreamController<String>.broadcast();
  Stream<String> get logs => _logs.stream;
  Process? _active;

  Future<CommandResult> runCommand(String command, List<String> args, {String? cwd}) async {
    if (command.isEmpty || command.contains('/') && !command.startsWith('/usr/bin/')) {
      throw ArgumentError('Invalid executable path');
    }
    final stdoutText = StringBuffer();
    final stderrText = StringBuffer();
    try {
      final process = await Process.start(command, args, workingDirectory: cwd, runInShell: false);
      _active = process;
      final output = process.stdout.transform(utf8.decoder).listen((text) {
        stdoutText.write(text);
        _logs.add(text);
      });
      final errors = process.stderr.transform(utf8.decoder).listen((text) {
        stderrText.write(text);
        _logs.add(text);
      });
      final exitCode = await process.exitCode;
      await Future.wait([output.asFuture<void>(), errors.asFuture<void>()]);
      return CommandResult(exitCode, stdoutText.toString(), stderrText.toString());
    } on ProcessException catch (error) {
      final message = 'Unable to run $command: ${error.message}';
      _logs.add(message);
      return CommandResult(127, '', message);
    } finally {
      _active = null;
    }
  }

  Future<CommandResult> runWithPkexec(String command, List<String> args) {
    final valid = switch (command) {
      '/usr/bin/apt-get' => args.length == 1 && args.first == 'update' ||
          args.length == 3 && {'install', 'remove'}.contains(args.first) &&
          args[1] == '-y' && PackageIds.validApt(args[2]),
      '/usr/bin/flatpak' => args.length == 5 && args[0] == 'install' &&
          args[1] == '--system' && args[2] == '-y' &&
          PackageIds.validFlatpak(args[3]) && PackageIds.validFlatpak(args[4]) ||
          args.length == 4 && args[0] == 'uninstall' &&
          args[1] == '--system' && args[2] == '-y' && PackageIds.validFlatpak(args[3]),
      _ => false,
    };
    if (!valid) {
      throw ArgumentError('Unapproved privileged package operation');
    }
    return runCommand('pkexec', [command, ...args]);
  }

  Future<bool> checkCommandExists(String command) async {
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(command)) return false;
    return (await runCommand('which', [command])).ok;
  }

  Future<bool> get hasFlatpak => checkCommandExists('flatpak');
  Future<bool> get hasApt => checkCommandExists('apt-get');
  Future<CommandResult> launchFlatpak(String ref) async {
    if (!PackageIds.validFlatpak(ref)) throw const FormatException('Invalid Flatpak identifier');
    try {
      final process = await Process.start('flatpak', ['run', ref],
          mode: ProcessStartMode.detached);
      _logs.add('Started $ref (PID ${process.pid})\n');
      return const CommandResult(0, '', '');
    } on ProcessException catch (exception) {
      _logs.add('${exception.message}\n');
      return CommandResult(127, '', exception.message);
    }
  }
  void stop() { _active?.kill(ProcessSignal.sigterm); }
  void dispose() { stop(); _logs.close(); }
}

class PackageService {
  PackageService(this.runner);
  final SystemRunner runner;
  bool _aptUpdated = false;

  Future<List<FlatpakSearchResult>> flatpakSearch(String query) async {
    final term = query.trim();
    if (term.length < 2 || term.length > 80 || !RegExp(r'^[\p{L}\p{N} ._+-]+$', unicode: true).hasMatch(term)) {
      throw const FormatException('Search requires 2–80 letters or digits');
    }
    final result = await runner.runCommand('flatpak',
        ['search', '--columns=application,name,description', term]);
    if (!result.ok) throw StateError(result.stderr.isEmpty ? 'Flathub search failed (${result.exitCode})' : result.stderr);
    return result.stdout.split('\n').skip(1).map((line) => line.split('\t'))
        .where((columns) => columns.length >= 3 && PackageIds.validFlatpak(columns[0]))
        .map((columns) => FlatpakSearchResult(columns[0], columns[1], columns[2]))
        .take(40).toList();
  }

  Future<CommandResult> aptInstall(String package) async {
    _aptId(package);
    if (!_aptUpdated) {
      final update = await runner.runWithPkexec('/usr/bin/apt-get', ['update']);
      if (!update.ok) return update;
      _aptUpdated = true;
    }
    return runner.runWithPkexec('/usr/bin/apt-get', ['install', '-y', package]);
  }

  Future<CommandResult> aptRemove(String package) {
    _aptId(package);
    return runner.runWithPkexec('/usr/bin/apt-get', ['remove', '-y', package]);
  }

  Future<bool> aptInstalled(String package) async {
    _aptId(package);
    final result = await runner.runCommand('dpkg-query', ['-W', '-f=\${Status}', package]);
    return result.ok && result.stdout.trim() == 'install ok installed';
  }

  Future<CommandResult> flatpakInstall(String remote, String ref) async {
    _flatpakId(remote);
    _flatpakId(ref);
    if (remote != 'flathub') throw const FormatException('Only Flathub is approved');
    final remotes = await runner.runCommand('flatpak', ['remotes', '--user', '--columns=name']);
    if (!remotes.ok || !remotes.stdout.split('\n').contains(remote)) {
      final added = await runner.runCommand('flatpak', [
        'remote-add', '--user', '--if-not-exists', '--from',
        remote, 'https://flathub.org/repo/flathub.flatpakrepo',
      ]);
      if (!added.ok) return added;
    }
    return runner.runCommand('flatpak', ['install', '--user', '-y', remote, ref]);
  }

  Future<CommandResult> flatpakRemove(String ref) async {
    _flatpakId(ref);
    final userInfo = await runner.runCommand('flatpak', ['info', '--user', ref]);
    if (userInfo.ok) return runner.runCommand('flatpak', ['uninstall', '--user', '-y', ref]);
    return runner.runWithPkexec('/usr/bin/flatpak', ['uninstall', '--system', '-y', ref]);
  }

  Future<bool> flatpakInstalled(String ref) async {
    _flatpakId(ref);
    return (await runner.runCommand('flatpak', ['info', ref])).ok;
  }

  Future<CommandResult> launchFlatpak(String ref) async {
    _flatpakId(ref);
    if (!await flatpakInstalled(ref)) return const CommandResult(1, '', 'App is not installed');
    return runner.launchFlatpak(ref);
  }

  void _aptId(String value) {
    if (!PackageIds.validApt(value)) throw FormatException('Invalid APT package identifier');
  }

  void _flatpakId(String value) {
    if (!PackageIds.validFlatpak(value)) throw FormatException('Invalid Flatpak identifier');
  }
}
