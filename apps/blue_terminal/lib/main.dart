import 'dart:async';
import 'package:blue_system/blue_system.dart';
import 'package:blue_ui/blue_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'command_policy.dart';
import 'terminal_model.dart';

void main() => runApp(BlueApp(title: 'Blue Terminal', builder: (context, language) => TerminalPage(language: language)));

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key, required this.language, this.model});
  final BlueLanguage language;
  final TerminalModel? model;
  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  late final SystemRunner runner;
  late final TerminalModel model;
  late final StreamSubscription<String> subscription;
  final input = TextEditingController();
  final directory = TextEditingController();
  @override
  void initState() {
    super.initState();
    runner = widget.model?.runner ?? SystemRunner();
    model = widget.model ?? TerminalModel(runner);
    directory.text = model.cwd;
    subscription = runner.logs.listen(model.append);
  }
  @override
  void dispose() {
    subscription.cancel(); input.dispose(); directory.dispose();
    if (widget.model == null) { model.dispose(); runner.dispose(); }
    super.dispose();
  }
  void submit(String value) { model.execute(value); input.clear(); }
  Future<void> toggleAdvanced(bool value) async {
    if (value) {
      final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('هشدار / Warning'),
        content: const Text('Advanced mode can modify files and system state. Shell syntax is not supported.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو / Cancel')),
          BlueButton(label: 'Enable', onPressed: () => Navigator.pop(context, true))],
      ));
      if (confirm != true) return;
    }
    model.toggleAdvanced(value);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: model, builder: (context, _) {
    final suggestions = input.text.isEmpty ? <String>[] : CommandPolicy.suggestions
        .where((item) => item.startsWith(input.text)).take(4).toList();
    return BlueScaffold(title: widget.language.text('ترمینال آبی', 'Blue Terminal'), actions: [
      IconButton(tooltip: 'English / فارسی', onPressed: widget.language.toggle, icon: const Icon(Icons.translate)),
    ], child: Column(children: [
      Row(children: [
        Expanded(child: BlueTextField(controller: directory, label: widget.language.text('پوشهٔ کاری', 'Working directory'), onSubmitted: model.changeDirectory)),
        IconButton(onPressed: () => model.changeDirectory(directory.text), icon: const Icon(Icons.folder_open)),
        Text(widget.language.text('حالت پیشرفته', 'Advanced mode')),
        Switch(value: model.advanced, onChanged: toggleAdvanced),
      ]),
      Wrap(spacing: 8, children: [
        BlueButton(label: widget.language.text('اطلاعات سیستم', 'System Info'), onPressed: model.busy ? null : model.systemInfo, icon: Icons.info_outline),
        BlueButton(label: widget.language.text('به‌روزرسانی', 'Update'), onPressed: model.busy ? null : model.update, icon: Icons.update),
        BlueButton(label: widget.language.text('پاک‌کردن', 'Clear'), onPressed: model.clear, icon: Icons.clear),
        BlueButton(label: widget.language.text('رونوشت', 'Copy output'), onPressed: () => Clipboard.setData(ClipboardData(text: model.output)), icon: Icons.copy),
        BlueButton(label: widget.language.text('توقف', 'Stop'), danger: true, onPressed: model.busy ? model.stop : null, icon: Icons.stop),
      ]),
      const SizedBox(height: 12),
      Expanded(child: BlueGlassCard(child: SizedBox.expand(child: SingleChildScrollView(reverse: true,
        child: SelectableText(model.output.isEmpty ? widget.language.text('دستوری وارد کنید', 'Enter a command') : model.output,
          textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'monospace', color: BlueColors.text))))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: input, onChanged: (_) => setState(() {}), onSubmitted: submit,
          decoration: InputDecoration(labelText: widget.language.text('فرمان (بدون شِل)', 'Command (no shell)')))),
        PopupMenuButton<String>(tooltip: widget.language.text('سابقه', 'History'), icon: const Icon(Icons.history),
          onSelected: (value) { input.text = value; setState(() {}); },
          itemBuilder: (context) => model.history.reversed.take(15)
              .map((entry) => PopupMenuItem(value: entry, child: Text(entry))).toList()),
        BlueButton(label: widget.language.text('اجرا', 'Run'), onPressed: model.busy ? null : () => submit(input.text), icon: Icons.play_arrow),
      ]),
      if (suggestions.isNotEmpty) Wrap(spacing: 6, children: suggestions.map((item) => ActionChip(label: Text(item), onPressed: () { input.text = item; setState(() {}); })).toList()),
      Text(widget.language.text('سابقه: ${model.history.length} دستور', 'History: ${model.history.length} commands')),
    ]));
  });
}
