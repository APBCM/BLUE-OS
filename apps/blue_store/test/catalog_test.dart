import 'package:blue_store/catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('bundled catalog includes categories and safe Flathub IDs', () async {
    final source = await rootBundle.loadString('assets/catalog/apps.fa.json');
    final apps = parseCatalog(source);
    expect(apps.length, greaterThanOrEqualTo(15));
    expect(apps.map((app) => app.category).toSet(),
        containsAll(['development', 'media', 'internet', 'tools']));
    expect(apps.every((app) => app.remote == 'flathub' && app.icon.isNotEmpty), isTrue);
  });
  test('parses local catalog entries', () {
    final apps = parseCatalog('[{"id":"vlc","name_fa":"وی‌ال‌سی","name_en":"VLC",'
      '"summary_fa":"ویدیو","summary_en":"Video","type":"apt",'
      '"apt":{"package":"vlc"},"popular":true}]');
    expect(apps.single.package, 'vlc');
    expect(apps.single.popular, isTrue);
  });
  test('rejects unsafe catalog packages', () {
    expect(() => parseCatalog('[{"id":"bad","name_fa":"بد","name_en":"Bad",'
      '"summary_fa":"بد","summary_en":"Bad","type":"apt",'
      '"apt":{"package":"vlc;rm"}}]'), throwsFormatException);
  });
}
