import 'dart:io';
import 'package:blue_system/blue_system.dart';
import 'package:blue_ui/blue_ui.dart';
import 'package:flutter/material.dart';
import 'file_service.dart';
import 'files_model.dart';

void main() => runApp(BlueApp(title: 'Blue Files', builder: (context, language) => FilesPage(language: language)));

class FilesPage extends StatefulWidget {
  const FilesPage({super.key, required this.language, this.model});
  final BlueLanguage language;
  final FilesModel? model;
  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  late final SystemRunner runner;
  late final FilesModel model;
  final pathInput = TextEditingController();
  @override
  void initState() {
    super.initState();
    runner = SystemRunner();
    model = widget.model ?? FilesModel(FileService(runner));
    pathInput.text = model.path;
    model.load();
  }
  @override
  void dispose() {
    pathInput.dispose();
    if (widget.model == null) model.dispose();
    runner.dispose(); super.dispose();
  }
  Future<void> navigate(String path) async { await model.load(path); pathInput.text = model.path; }

  Future<String?> askName(String title, [String initial = '']) async {
    final controller = TextEditingController(text: initial);
    final answer = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: Text(title), content: BlueTextField(controller: controller, label: title),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو / Cancel')),
        BlueButton(label: 'تأیید / OK', onPressed: () => Navigator.pop(context, controller.text))],
    ));
    controller.dispose(); return answer;
  }

  Future<void> action(FileItem item, String value) async {
    if (value == 'copy' || value == 'cut') { model.select(item.entity, move: value == 'cut'); return; }
    if (value == 'rename') {
      final name = await askName('نام جدید / New name', item.name);
      if (name != null) await model.perform(() => model.service.rename(item.entity, name));
    }
    if (value == 'trash') {
      final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('انتقال به سطل زباله؟ / Move to trash?'),
        content: Text(item.name),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو / Cancel')),
          BlueButton(label: 'انتقال / Move', danger: true, onPressed: () => Navigator.pop(context, true))],
      ));
      if (confirm == true) await model.perform(() => model.service.trash(item.entity));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: model, builder: (context, _) {
    final home = Platform.environment['HOME'] ?? '/home';
    final places = <(String, String, IconData)>[
      (widget.language.text('خانه', 'Home'), home, Icons.home_outlined),
      (widget.language.text('دریافت‌ها', 'Downloads'), '$home/Downloads', Icons.download_outlined),
      (widget.language.text('اسناد', 'Documents'), '$home/Documents', Icons.description_outlined),
      (widget.language.text('تصاویر', 'Pictures'), '$home/Pictures', Icons.image_outlined),
      (widget.language.text('ویدیوها', 'Videos'), '$home/Videos', Icons.movie_outlined),
      (widget.language.text('موسیقی', 'Music'), '$home/Music', Icons.music_note_outlined),
    ];
    return BlueScaffold(title: widget.language.text('پرونده‌های آبی', 'Blue Files'), actions: [
      IconButton(tooltip: 'English / فارسی', onPressed: widget.language.toggle, icon: const Icon(Icons.translate)),
    ], child: Row(children: [
      SizedBox(width: 210, child: BlueGlassCard(child: ListView(children: [
        for (final place in places) BlueListTile(title: place.$1, icon: place.$3, onTap: () => navigate(place.$2)),
        BlueListTile(title: widget.language.text('سطل زباله', 'Trash'), icon: Icons.delete_outline,
          onTap: () => runner.runCommand('xdg-open', ['trash:///'])),
      ]))),
      const SizedBox(width: 16),
      Expanded(child: Column(children: [
        Row(children: [
          IconButton(onPressed: () => navigate(Directory(model.path).parent.path), icon: const Icon(Icons.arrow_upward)),
          Expanded(child: BlueTextField(controller: pathInput, label: widget.language.text('مسیر', 'Path'), onSubmitted: navigate)),
          IconButton(tooltip: 'Go', onPressed: () => navigate(pathInput.text), icon: const Icon(Icons.arrow_forward)),
          IconButton(tooltip: 'Paste', onPressed: model.clipboard == null || model.busy ? null : model.paste, icon: const Icon(Icons.content_paste)),
          IconButton(tooltip: 'New folder', onPressed: model.busy ? null : () async {
            final name = await askName('پوشهٔ جدید / New folder');
            if (name != null) await model.perform(() => model.service.newFolder(model.path, name));
          }, icon: const Icon(Icons.create_new_folder_outlined)),
          DropdownButton<FileSort>(value: model.sort, items: const [
            DropdownMenuItem(value: FileSort.name, child: Text('Name / نام')),
            DropdownMenuItem(value: FileSort.date, child: Text('Date / تاریخ')),
            DropdownMenuItem(value: FileSort.size, child: Text('Size / اندازه')),
          ], onChanged: (value) { if (value != null) model.sortBy(value); }),
        ]),
        if (model.error != null) Text(model.error!, style: const TextStyle(color: BlueColors.danger)),
        if (model.busy) const LinearProgressIndicator(),
        Expanded(child: ListView.builder(itemCount: model.items.length, itemBuilder: (context, index) {
          final item = model.items[index];
          return BlueListTile(title: item.name,
            subtitle: '${item.directory ? "—" : "${item.size} B"}   •   ${item.modified.toLocal()}',
            icon: item.directory ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
            onTap: () => item.directory ? navigate(item.entity.path) : model.perform(() => model.service.open(item.entity)),
            trailing: PopupMenuButton<String>(onSelected: (value) => action(item, value), itemBuilder: (context) => const [
              PopupMenuItem(value: 'copy', child: Text('Copy / کپی')),
              PopupMenuItem(value: 'cut', child: Text('Cut / برش')),
              PopupMenuItem(value: 'rename', child: Text('Rename / تغییر نام')),
              PopupMenuItem(value: 'trash', child: Text('Trash / سطل زباله')),
            ]));
        })),
      ])),
    ]));
  });
}
