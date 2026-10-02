import 'dart:io';
import 'package:blue_system/blue_system.dart';
import 'package:flutter/foundation.dart';
import 'command_policy.dart';

class TerminalModel extends ChangeNotifier {
  TerminalModel(this.runner) : cwd = Platform.environment['HOME'] ?? '/home';
  final SystemRunner runner;
  String cwd;
  String output = '';
  bool busy = false;
  bool advanced = false;
  final history = <String>[];
  int historyIndex = 0;

  void toggleAdvanced(bool value) { advanced = value; notifyListeners(); }
  void append(String text) { output = (output + text).length > 100000 ? (output + text).substring((output + text).length - 100000) : output + text; notifyListeners(); }
  void clear() { output = ''; notifyListeners(); }
  Future<void> changeDirectory(String path) async {
    if (!await Directory(path).exists()) { append('Directory not found: $path\n'); return; }
    cwd = await Directory(path).resolveSymbolicLinks(); notifyListeners();
  }

  Future<void> execute(String input) async {
    if (busy) return;
    try {
      final parts = CommandPolicy.tokenize(input);
      CommandPolicy.validate(parts, advanced: advanced);
      history.add(input); historyIndex = history.length;
      busy = true; append('> $input\n');
      final result = await runner.runCommand(parts.first, parts.skip(1).toList(), cwd: cwd);
      if (!result.ok) append('[exit ${result.exitCode}] ${result.stderr}\n');
    } catch (error) { append('Error: $error\n'); }
    busy = false; notifyListeners();
  }

  Future<void> systemInfo() async {
    for (final entry in [('uname', ['-a']), ('lsb_release', ['-a'])]) {
      if (busy) return;
      busy = true; notifyListeners();
      final result = await runner.runCommand(entry.$1, entry.$2, cwd: cwd);
      if (!result.ok) append('[exit ${result.exitCode}] ${result.stderr}\n');
      busy = false; notifyListeners();
    }
  }

  Future<void> update() async {
    if (busy) return;
    busy = true; notifyListeners();
    final result = await runner.runWithPkexec('/usr/bin/apt-get', ['update']);
    if (!result.ok) append('[exit ${result.exitCode}] ${result.stderr}\n');
    busy = false; notifyListeners();
  }

  void stop() { runner.stop(); append('Process stopped.\n'); }
}
