import 'package:blue_store/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
