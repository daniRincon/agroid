import 'package:hive/hive.dart';

part 'admin_api_config.g.dart';

@HiveType(typeId: 2)
class AdminApiConfig extends HiveObject {
  @HiveField(0)
  final String endpointUrl;
  @HiveField(1)
  final String? apiKey;
  @HiveField(2)
  final String? customHeader;

  AdminApiConfig({
    required this.endpointUrl,
    this.apiKey,
    this.customHeader,
  });
}
