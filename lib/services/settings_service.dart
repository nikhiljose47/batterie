import 'package:flutter_dotenv/flutter_dotenv.dart';

class SettingsService {
  String? getApiKey() => dotenv.env['OPEN_ROUTER_API_KEY'];
}
