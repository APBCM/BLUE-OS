import 'package:blue_system/blue_system.dart';
import 'package:blue_terminal/main.dart';
import 'package:blue_terminal/terminal_model.dart';
import 'package:blue_ui/blue_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class StubRunner extends SystemRunner {
  @override
  Future<CommandResult> runCommand(String command, List<String> args, {String? cwd}) async =>
      const CommandResult(0, 'test', '');
}

void main() {
  testWidgets('terminal starts in guarded mode', (tester) async {
    final runner = StubRunner();
    final model = TerminalModel(runner);
    final language = BlueLanguage();
    await tester.pumpWidget(BlueApp(title: 'Terminal', builder: (context, _) => TerminalPage(language: language, model: model)));
    expect(find.text('ترمینال آبی'), findsOneWidget);
    expect(model.advanced, isFalse);
    await model.execute('pwd');
    await tester.pump();
    expect(model.history, ['pwd']);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose(); runner.dispose(); language.dispose();
  });
}
