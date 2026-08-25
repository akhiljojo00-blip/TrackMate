import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/providers/connection_provider.dart';

void main() {
  group('User Search Debouncing & Concurrency Guard Tests', () {
    test('Queries shorter than 2 characters immediately clear results and cancel timers', () {
      final provider = ConnectionProvider();

      // Typing single character
      provider.searchUsers('a', 'user_current');
      expect(provider.isSearching, isFalse);
      expect(provider.searchResults, isEmpty);
      expect(provider.activeSearchToken, greaterThan(0));

      // Empty query
      provider.searchUsers('   ', 'user_current');
      expect(provider.isSearching, isFalse);
      expect(provider.searchResults, isEmpty);
    });

    test('Rapid sequential typing triggers debouncer and advances active token', () async {
      final provider = ConnectionProvider();
      final initialToken = provider.activeSearchToken;

      // Simulate rapid typing with custom short debounce to test mechanics
      provider.searchUsers('a', 'user_current', debounceDuration: const Duration(milliseconds: 50));
      await Future.delayed(const Duration(milliseconds: 10));

      provider.searchUsers('ak', 'user_current', debounceDuration: const Duration(milliseconds: 50));
      expect(provider.isSearching, isTrue);
      final tokenAk = provider.activeSearchToken;
      expect(tokenAk, greaterThan(initialToken));
      await Future.delayed(const Duration(milliseconds: 10));

      provider.searchUsers('akh', 'user_current', debounceDuration: const Duration(milliseconds: 50));
      expect(provider.isSearching, isTrue);
      final tokenAkh = provider.activeSearchToken;
      expect(tokenAkh, greaterThan(tokenAk));
      await Future.delayed(const Duration(milliseconds: 10));

      provider.searchUsers('akhi', 'user_current', debounceDuration: const Duration(milliseconds: 50));
      expect(provider.isSearching, isTrue);
      final tokenAkhi = provider.activeSearchToken;
      expect(tokenAkhi, greaterThan(tokenAkh));

      // Wait for debounce timer to expire
      await Future.delayed(const Duration(milliseconds: 80));

      // Token matches the final query
      expect(provider.activeSearchToken, equals(tokenAkhi));
    });

    test('clearSearch immediately cancels debounce and resets state', () async {
      final provider = ConnectionProvider();

      provider.searchUsers('john', 'user_current', debounceDuration: const Duration(milliseconds: 100));
      expect(provider.isSearching, isTrue);
      final tokenBefore = provider.activeSearchToken;

      provider.clearSearch();
      expect(provider.isSearching, isFalse);
      expect(provider.searchResults, isEmpty);
      expect(provider.searchError, isNull);
      expect(provider.activeSearchToken, greaterThan(tokenBefore));

      // Wait past debounce duration to verify cancelled timer never runs
      await Future.delayed(const Duration(milliseconds: 150));
      expect(provider.isSearching, isFalse);
      expect(provider.searchResults, isEmpty);
    });

    test('clear() resets active search state and advances token', () {
      final provider = ConnectionProvider();
      provider.searchUsers('alex', 'user_current');
      final tokenBefore = provider.activeSearchToken;

      provider.clear();
      expect(provider.isSearching, isFalse);
      expect(provider.searchResults, isEmpty);
      expect(provider.activeSearchToken, greaterThan(tokenBefore));
    });
  });
}
