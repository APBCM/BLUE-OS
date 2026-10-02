import 'package:blue_store/catalog.dart';
import 'package:blue_store/main.dart';
import 'package:blue_store/store_model.dart';
import 'package:blue_system/blue_system.dart';
import 'package:blue_ui/blue_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRunner extends SystemRunner {
  @override
  Future<bool> get hasFlatpak async => true;
  @override
  Future<CommandResult> runCommand(String command, List<String> args, {String? cwd}) async =>
      const CommandResult(1, '', 'not installed');
}

void main() {
  testWidgets('store shows Persian catalog and search', (tester) async {
    final runner = FakeRunner();
    final model = StoreModel(PackageService(runner), loader: () async => [
      const CatalogApp(id: 'vlc', nameFa: 'وی‌ال‌سی', nameEn: 'VLC', summaryFa: 'ویدیو',
        summaryEn: 'Video', type: 'apt', package: 'vlc', remote: '', popular: true),
    ]);
    final language = BlueLanguage();
    await tester.pumpWidget(BlueApp(title: 'Store', builder: (context, _) => StorePage(language: language, model: model)));
    await tester.pumpAndSettle();
    expect(find.text('وی‌ال‌سی'), findsOneWidget);
    expect(find.text('محبوب‌ترین‌ها'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'no match');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('وی‌ال‌سی'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose(); runner.dispose(); language.dispose();
  });
}
