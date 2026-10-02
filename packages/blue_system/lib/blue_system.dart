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

class PackageIds {
  static final apt = RegExp(r'^[a-z0-9][a-z0-9+.-]+$');
  static final flatpak = RegExp(r'^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)?$');
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
    if (!{'/usr/bin/apt-get', '/usr/bin/flatpak'}.contains(command)) {
      throw ArgumentError('Privileged executable must be an approved absolute path');
    }
    return runCommand('pkexec', [command, ...args]);
  }

  Future<bool> checkCommandExists(String command) async {
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(command)) return false;
    return (await runCommand('which', [command])).ok;
  }

  Future<bool> get hasFlatpak => checkCommandExists('flatpak');
  Future<bool> get hasApt => checkCommandExists('apt-get');
  void stop() { _active?.kill(ProcessSignal.sigterm); }
  void dispose() { stop(); _logs.close(); }
}

class PackageService {
  PackageService(this.runner);
  final SystemRunner runner;
  bool _aptUpdated = false;

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
    final remotes = await runner.runCommand('flatpak', ['remotes', '--user', '--columns=name']);
    if (remotes.stdout.split('\n').contains(remote)) {
      return runner.runCommand('flatpak', ['install', '--user', '-y', remote, ref]);
    }
    return runner.runWithPkexec('/usr/bin/flatpak', ['install', '--system', '-y', remote, ref]);
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

  void _aptId(String value) {
    if (!PackageIds.validApt(value)) throw FormatException('Invalid APT package identifier');
  }

  void _flatpakId(String value) {
    if (!PackageIds.validFlatpak(value)) throw FormatException('Invalid Flatpak identifier');
  }
}
