import '../../core/network/api_response.dart';
import '../model/search_result.dart';

/// Contract for search data access and persistence operations.
abstract class SearchRepository {
  Future<ApiResponse<List<SearchResult>>> searchHome(String query);
  Future<ApiResponse<List<SearchResult>>> searchStore99(String query);
  Future<List<String>> getRecentSearches();
  Future<void> saveRecentSearch(String query);
  Future<void> clearRecentSearches();
  Future<void> removeRecentSearch(String query);
}
