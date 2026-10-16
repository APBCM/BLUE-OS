import 'package:blue_system/blue_system.dart';
import 'package:test/test.dart';

void main() {
  test('APT identifiers are allow-listed', () {
    expect(PackageIds.validApt('libgtk-3-0'), isTrue);
    expect(PackageIds.validApt('a'), isFalse);
    expect(PackageIds.validApt('vlc;rm -rf /'), isFalse);
    expect(PackageIds.validApt('--option'), isFalse);
  });
  test('Flatpak IDs reject command injection', () {
    expect(PackageIds.validFlatpak('org.gnome.Calculator/x86_64'), isTrue);
    expect(PackageIds.validFlatpak('org.gnome.Calculator;echo'), isFalse);
    expect(PackageIds.validFlatpak('../relative'), isFalse);
  });
  test('package service never starts invalid IDs', () async {
    final packages = PackageService(SystemRunner());
    await expectLater(packages.aptInstall('vlc;echo'), throwsFormatException);
    await expectLater(packages.flatpakInstall('flathub', '../bad'), throwsFormatException);
  });
  test('privileged commands reject arbitrary flags and executables', () {
    final runner = SystemRunner();
    expect(() => runner.runWithPkexec('/usr/bin/sh', ['-c', 'id']), throwsArgumentError);
    expect(() => runner.runWithPkexec('/usr/bin/flatpak', ['install', '--system', '-y', 'flathub', '--filesystem=host']), throwsArgumentError);
    runner.dispose();
  });
  test('Flathub search validates query before spawning a process', () async {
    final runner = SystemRunner();
    final packages = PackageService(runner);
    await expectLater(packages.flatpakSearch('--filesystem=host'), throwsFormatException);
    await expectLater(packages.flatpakSearch('x'), throwsFormatException);
    runner.dispose();
  });
  test('launch rejects unsafe Flatpak identifiers', () async {
    final runner = SystemRunner();
    await expectLater(runner.launchFlatpak('--command=sh'), throwsFormatException);
    runner.dispose();
  });
}
