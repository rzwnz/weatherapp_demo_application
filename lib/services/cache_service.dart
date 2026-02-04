import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_model.dart';

/// Service class for caching weather data locally
class CacheService {
  static const String _cacheKey = 'cached_weather';
  static const String _lastCityKey = 'last_city';

  /// Save weather data to cache
  Future<void> cacheWeather(WeatherModel weather) async {
    final prefs = await SharedPreferences.getInstance();
    final weatherJson = jsonEncode(weather.toJson());
    await prefs.setString(_cacheKey, weatherJson);
    await prefs.setString(_lastCityKey, weather.cityName);
  }

  /// Load weather data from cache
  Future<WeatherModel?> getCachedWeather() async {
    final prefs = await SharedPreferences.getInstance();
    final weatherJson = prefs.getString(_cacheKey);
    
    if (weatherJson == null) {
      return null;
    }

    try {
      final json = jsonDecode(weatherJson) as Map<String, dynamic>;
      return WeatherModel.fromJson(json, isFromCache: true);
    } catch (e) {
      // If cache is corrupted, return null
      return null;
    }
  }

  /// Get last searched city name
  Future<String?> getLastCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastCityKey);
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_lastCityKey);
  }

  /// Check if cache exists
  Future<bool> hasCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_cacheKey);
  }
}
