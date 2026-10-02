import 'package:blue_files/file_service.dart';
import 'package:blue_files/files_model.dart';
import 'package:blue_files/main.dart';
import 'package:blue_system/blue_system.dart';
import 'package:blue_ui/blue_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class EmptyFiles extends FileService {
  EmptyFiles() : super(SystemRunner());
  @override
  Future<List<FileItem>> list(String path) async => [];
}

void main() {
  testWidgets('file manager shows places and path', (tester) async {
    final language = BlueLanguage();
    final model = FilesModel(EmptyFiles(), initialPath: '/tmp');
    await tester.pumpWidget(BlueApp(title: 'Files', builder: (context, _) => FilesPage(language: language, model: model)));
    await tester.pumpAndSettle();
    expect(find.text('خانه'), findsOneWidget);
    expect(find.text('سطل زباله'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose(); language.dispose();
  });
}
