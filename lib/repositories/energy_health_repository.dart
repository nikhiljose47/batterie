import '../models/battery_status.dart';
import '../models/body_status.dart';
import '../models/news_article.dart';
import '../models/person_status.dart';
import '../services/energy_health_service.dart';

class EnergyHealthRepository {
  const EnergyHealthRepository({
    this.service = const EnergyHealthService(),
  });

  final EnergyHealthService service;

  Future<BodyStatus> getBodyStatus() {
    return service.fetchBodyStatus();
  }

  Future<List<BatteryStatus>> getBatteryStatuses() {
    return service.fetchBatteryStatuses();
  }

  Future<List<PersonStatus>> getPeopleStatuses() {
    return service.fetchPeopleStatuses();
  }

  Future<List<NewsArticle>> getNewsArticles() {
    return service.fetchNewsArticles();
  }
}
