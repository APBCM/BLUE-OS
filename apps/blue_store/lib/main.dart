import 'dart:async';
import 'package:blue_system/blue_system.dart';
import 'package:blue_ui/blue_ui.dart';
import 'package:flutter/material.dart';
import 'catalog.dart';
import 'store_model.dart';

void main() => runApp(BlueApp(title: 'Blue Store', builder: (context, language) => StorePage(language: language)));

class StorePage extends StatefulWidget {
  const StorePage({super.key, required this.language, this.model});
  final BlueLanguage language;
  final StoreModel? model;
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  late final SystemRunner runner;
  late final StoreModel model;
  late final StreamSubscription<String> subscription;
  final search = TextEditingController();
  String logs = '';
  @override
  void initState() {
    super.initState();
    runner = widget.model?.packages.runner ?? SystemRunner();
    model = widget.model ?? StoreModel(PackageService(runner));
    search.addListener(() { if (mounted) setState(() {}); });
    subscription = runner.logs.listen((line) { if (mounted) setState(() => logs = (logs + line).length > 12000 ? (logs + line).substring((logs + line).length - 12000) : logs + line); });
    model.initialize();
  }
  @override
  void dispose() {
    subscription.cancel(); search.dispose();
    if (widget.model == null) { model.dispose(); runner.dispose(); }
    super.dispose();
  }

  Widget appTile(CatalogApp app) => BlueListTile(
    title: widget.language.text(app.nameFa, app.nameEn),
    subtitle: widget.language.text(app.summaryFa, app.summaryEn),
    icon: app.type == 'apt' ? Icons.inventory_2_outlined : Icons.widgets_outlined,
    trailing: Icon((model.installed[app.id] ?? false) ? Icons.check_circle : Icons.chevron_right),
    onTap: () => showDialog<void>(context: context, builder: (context) => AlertDialog(
      backgroundColor: BlueColors.panel,
      title: Text(widget.language.text(app.nameFa, app.nameEn)),
      content: Text('${widget.language.text(app.summaryFa, app.summaryEn)}\n${app.type.toUpperCase()}: ${app.package}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.language.text('بستن', 'Close'))),
        BlueButton(label: (model.installed[app.id] ?? false)
            ? widget.language.text('حذف', 'Remove') : widget.language.text('نصب', 'Install'),
          danger: model.installed[app.id] ?? false,
          onPressed: model.busy || (app.type == 'flatpak' && !model.flatpakAvailable) ? null : () {
            Navigator.pop(context); model.change(app);
          }),
      ],
    )),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: model, builder: (context, _) {
    final query = search.text.trim().toLowerCase();
    final found = model.apps.where((app) => '${app.nameFa} ${app.nameEn} ${app.summaryFa} ${app.summaryEn}'.toLowerCase().contains(query)).toList();
    return BlueScaffold(title: widget.language.text('فروشگاه آبی', 'Blue Store'), actions: [
      IconButton(tooltip: 'English / فارسی', onPressed: widget.language.toggle, icon: const Icon(Icons.translate)),
    ], child: Column(children: [
      BlueTextField(controller: search, label: widget.language.text('جست‌وجوی برنامه', 'Search apps'), onSubmitted: (_) => setState(() {})),
      const SizedBox(height: 12),
      if (!model.flatpakAvailable) BlueGlassCard(child: Row(children: [
        const Expanded(child: Text('Flatpak نصب نیست / Flatpak is not installed')),
        BlueButton(label: widget.language.text('نصب Flatpak', 'Install Flatpak'), onPressed: model.busy ? null : model.installFlatpak),
      ])),
      if (model.error != null) Text(model.error!, style: const TextStyle(color: BlueColors.danger)),
      if (model.busy) const LinearProgressIndicator(),
      Expanded(child: ListView(children: [
        if (query.isEmpty) ...[
          Text(widget.language.text('محبوب‌ترین‌ها', 'Popular'), style: Theme.of(context).textTheme.titleLarge),
          ...found.where((app) => app.popular).map(appTile),
          const SizedBox(height: 12),
          Text(widget.language.text('پیشنهادی‌ها', 'Recommended'), style: Theme.of(context).textTheme.titleLarge),
        ],
        ...found.where((app) => query.isNotEmpty || !app.popular).map(appTile),
      ])),
      SizedBox(height: 110, child: BlueGlassCard(child: SingleChildScrollView(reverse: true,
        child: SelectableText(logs.isEmpty ? widget.language.text('گزارش عملیات اینجا نمایش داده می‌شود', 'Operation log appears here') : logs,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11))))),
    ]));
  });
}
