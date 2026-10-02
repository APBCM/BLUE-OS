class CommandPolicy {
  static const allowed = ['ls', 'pwd', 'whoami', 'df', 'free', 'ip', 'ping', 'apt', 'flatpak', 'systemctl', 'journalctl'];
  static const suggestions = ['ls', 'pwd', 'whoami', 'df -h', 'free -h', 'ip addr', 'ping example.com',
    'apt search', 'flatpak list', 'systemctl status', 'journalctl -n 50'];

  static List<String> tokenize(String input) {
    if (input.trim().isEmpty || RegExp(r'[;&|<>$`\n\r]').hasMatch(input)) {
      throw const FormatException('Shell syntax is not supported');
    }
    return input.trim().split(RegExp(r'\s+'));
  }

  static void validate(List<String> parts, {required bool advanced}) {
    final command = parts.first;
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(command) ||
        ['sh', 'bash', 'zsh', 'fish', 'dash', 'sudo', 'pkexec', 'su'].contains(command)) {
      throw const FormatException('Executable is not allowed');
    }
    if (advanced) return;
    if (!allowed.contains(command)) throw const FormatException('Enable Advanced mode for this command');
    final args = parts.skip(1).toList();
    if (args.any((arg) => arg.startsWith('-') && arg.contains('='))) {
      throw const FormatException('This option requires Advanced mode');
    }
    if (command == 'apt' && (args.isEmpty || !['search', 'show', 'list'].contains(args.first))) {
      throw const FormatException('APT is read-only in normal mode');
    }
    if (command == 'apt' && args.skip(1).any((arg) => arg.startsWith('-'))) {
      throw const FormatException('APT options require Advanced mode');
    }
    if (command == 'flatpak' && (args.isEmpty || !['search', 'info', 'list', 'remotes'].contains(args.first))) {
      throw const FormatException('Flatpak is read-only in normal mode');
    }
    if (command == 'flatpak' && args.skip(1).any((arg) => arg.startsWith('-'))) {
      throw const FormatException('Flatpak options require Advanced mode');
    }
    if (command == 'systemctl' && (args.isEmpty || !['status', 'is-active', 'list-units', 'list-unit-files'].contains(args.first))) {
      throw const FormatException('systemctl is read-only in normal mode');
    }
    if (command == 'ip' && (args.isEmpty || !['addr', 'address', 'route', 'link'].contains(args.first) ||
        args.skip(1).any((arg) => !['show', 'list', '-br', '-s'].contains(arg)))) {
      throw const FormatException('ip is read-only in normal mode');
    }
    if (command == 'journalctl' && args.any((arg) => !['-n', '-u', '--no-pager', '--since', '--until'].contains(arg) &&
        (arg.startsWith('-') || arg.startsWith('--')))) {
      throw const FormatException('journalctl options are restricted');
    }
    if (command == 'ping' && args.any((arg) => arg.startsWith('-'))) {
      throw const FormatException('ping options require Advanced mode');
    }
  }
}
