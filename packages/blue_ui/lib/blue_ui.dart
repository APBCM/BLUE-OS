library blue_ui;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BlueColors {
  static const navy = Color(0xFF0B132B);
  static const cyan = Color(0xFF00A8FF);
  static const panel = Color(0xFF1C2541);
  static const muted = Color(0xFF3A506B);
  static const text = Color(0xFFEAF2FF);
  static const danger = Color(0xFFFF4D6D);
}

class BlueSpace {
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
}

class BlueTheme {
  static ThemeData get data => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: BlueColors.navy,
        colorScheme: const ColorScheme.dark(primary: BlueColors.cyan, surface: BlueColors.panel, error: BlueColors.danger),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: BlueColors.text),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: BlueColors.text),
          bodyMedium: TextStyle(fontSize: 14, color: BlueColors.text),
        ),
        iconTheme: const IconThemeData(color: BlueColors.cyan, size: 22),
        useMaterial3: true,
      );
}

class BlueScaffold extends StatelessWidget {
  const BlueScaffold({super.key, required this.title, required this.child, this.actions});
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: BlueAppBar(title: title, actions: actions),
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [BlueColors.navy, BlueColors.panel], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Padding(padding: const EdgeInsets.all(BlueSpace.large), child: child),
        ),
      );
}

class BlueAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BlueAppBar({super.key, required this.title, this.actions});
  final String title;
  final List<Widget>? actions;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: BlueColors.navy,
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        actions: actions,
      );
}

class BlueGlassCard extends StatelessWidget {
  const BlueGlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: BlueColors.panel.withOpacity(.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BlueColors.cyan.withOpacity(.28)),
              boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: child,
          ),
        ),
      );
}

class BlueButton extends StatelessWidget {
  const BlueButton({super.key, required this.label, required this.onPressed, this.icon, this.danger = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: danger ? BlueColors.danger : BlueColors.cyan, foregroundColor: BlueColors.navy),
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward),
        label: Text(label),
      );
}

class BlueTextField extends StatelessWidget {
  const BlueTextField({super.key, required this.controller, required this.label, this.onSubmitted});
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSubmitted;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(labelText: label, filled: true, fillColor: BlueColors.panel,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
      );
}

class BlueListTile extends StatelessWidget {
  const BlueListTile({super.key, required this.title, this.subtitle, this.icon = Icons.apps, this.onTap, this.trailing});
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: BlueColors.cyan), title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!), trailing: trailing, onTap: onTap,
      );
}

class BlueLanguage extends ChangeNotifier {
  Locale locale = const Locale('fa', 'IR');
  void toggle() { locale = locale.languageCode == 'fa' ? const Locale('en', 'US') : const Locale('fa', 'IR'); notifyListeners(); }
  String text(String persian, String english) => locale.languageCode == 'fa' ? persian : english;
}

class BlueApp extends StatefulWidget {
  const BlueApp({super.key, required this.title, required this.builder});
  final String title;
  final Widget Function(BuildContext, BlueLanguage) builder;
  @override
  State<BlueApp> createState() => _BlueAppState();
}

class _BlueAppState extends State<BlueApp> {
  final language = BlueLanguage();
  @override
  void dispose() { language.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: language,
        builder: (context, _) => MaterialApp(
          title: widget.title,
          theme: BlueTheme.data,
          debugShowCheckedModeBanner: false,
          locale: language.locale,
          supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: language.locale.languageCode == 'fa' ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
          home: Builder(builder: (context) => widget.builder(context, language)),
        ),
      );
}
