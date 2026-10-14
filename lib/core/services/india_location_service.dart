import 'dart:convert';
import 'package:flutter/services.dart';

class StateLocation {
  final String state;
  final List<String> districts;

  const StateLocation({
    required this.state,
    required this.districts,
  });

  factory StateLocation.fromJson(Map<String, dynamic> json) {
    final rawDistricts = json['districts'];
    final List<String> parsedDistricts;
    if (rawDistricts is List) {
      parsedDistricts = rawDistricts
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      parsedDistricts = const [];
    }

    return StateLocation(
      state: json['state']?.toString().trim() ?? '',
      districts: parsedDistricts,
    );
  }
}

class IndiaLocationService {
  final AssetBundle _bundle;
  List<StateLocation>? _cachedLocations;

  IndiaLocationService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Loads the location data from the bundled JSON asset.
  /// Result is cached in-memory after first load.
  Future<List<StateLocation>> loadLocations() async {
    if (_cachedLocations != null) {
      return _cachedLocations!;
    }

    try {
      final jsonString = await _bundle.loadString(
        'assets/india_states_districts.json',
      );
      final dynamic decoded = jsonDecode(jsonString);

      if (decoded is Map<String, dynamic> && decoded['states'] is List) {
        final list = decoded['states'] as List<dynamic>;
        final parsed = list
            .whereType<Map<String, dynamic>>()
            .map((item) => StateLocation.fromJson(item))
            .where((loc) => loc.state.isNotEmpty)
            .toList();

        // Sort states alphabetically
        parsed.sort((a, b) => a.state.compareTo(b.state));
        _cachedLocations = parsed;
      } else {
        _cachedLocations = const [];
      }
    } catch (_) {
      _cachedLocations = const [];
    }

    return _cachedLocations!;
  }

  /// Returns an alphabetically sorted list of all state and union territory names.
  Future<List<String>> getStates() async {
    final locations = await loadLocations();
    return locations.map((loc) => loc.state).toList();
  }

  /// Returns an alphabetically sorted list of districts for the given state name.
  /// If the state is not found or empty, returns an empty list.
  Future<List<String>> getDistrictsForState(String stateName) async {
    final trimmedState = stateName.trim();
    if (trimmedState.isEmpty) return const [];

    final locations = await loadLocations();
    final match = locations.firstWhere(
      (loc) => loc.state.toLowerCase() == trimmedState.toLowerCase(),
      orElse: () => const StateLocation(state: '', districts: []),
    );

    final sortedDistricts = List<String>.from(match.districts)..sort();
    return sortedDistricts;
  }
}
