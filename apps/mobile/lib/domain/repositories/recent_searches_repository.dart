abstract class RecentSearchesRepository {
  Future<List<String>> load();
  Future<void> save(List<String> items);
}
