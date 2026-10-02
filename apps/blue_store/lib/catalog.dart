import 'dart:convert';
import 'package:blue_system/blue_system.dart';
import 'package:flutter/services.dart';

class CatalogApp {
  const CatalogApp({required this.id, required this.nameFa, required this.nameEn,
    required this.summaryFa, required this.summaryEn, required this.type,
    required this.package, required this.remote, required this.popular});
  final String id, nameFa, nameEn, summaryFa, summaryEn, type, package, remote;
  final bool popular;
  factory CatalogApp.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    if (type != 'apt' && type != 'flatpak') throw const FormatException('Unknown package type');
    final package = type == 'apt'
        ? (json['apt'] as Map<String, dynamic>)['package'] as String
        : (json['flatpak'] as Map<String, dynamic>)['ref'] as String;
    final remote = type == 'flatpak' ? (json['flatpak'] as Map<String, dynamic>)['remote'] as String : '';
    if (type == 'apt' ? !PackageIds.validApt(package)
        : !PackageIds.validFlatpak(package) || !PackageIds.validFlatpak(remote)) {
      throw const FormatException('Unsafe catalog identifier');
    }
    return CatalogApp(id: json['id'] as String, nameFa: json['name_fa'] as String,
      nameEn: json['name_en'] as String, summaryFa: json['summary_fa'] as String,
      summaryEn: json['summary_en'] as String, type: type, package: package,
      remote: remote, popular: json['popular'] as bool? ?? false);
  }
}

List<CatalogApp> parseCatalog(String source) =>
    (jsonDecode(source) as List<dynamic>).map((item) => CatalogApp.fromJson(item as Map<String, dynamic>)).toList();

Future<List<CatalogApp>> loadCatalog() async => parseCatalog(
  await rootBundle.loadString('assets/catalog/apps.fa.json'),
);
