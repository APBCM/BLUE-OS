import 'package:blue_terminal/command_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normal mode blocks destructive commands', () {
    expect(() => CommandPolicy.validate(['apt', 'remove', 'vlc'], advanced: false), throwsFormatException);
    expect(() => CommandPolicy.validate(['systemctl', 'stop', 'ssh'], advanced: false), throwsFormatException);
    expect(() => CommandPolicy.validate(['apt', 'search', 'vlc'], advanced: false), returnsNormally);
  });
  test('shell syntax and shells never run', () {
    expect(() => CommandPolicy.tokenize('ls; rm -rf /'), throwsFormatException);
    expect(() => CommandPolicy.validate(['bash', '-c', 'echo'], advanced: true), throwsFormatException);
  });
}
