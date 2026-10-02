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
}
