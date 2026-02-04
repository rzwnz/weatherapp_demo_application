import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

/// Custom exception for weather API errors
class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);

  @override
  String toString() => message;
}

/// Service class for fetching weather data from OpenWeatherMap API
class WeatherService {
  // OpenWeatherMap API key - you can replace this with your own key
  static const String _apiKey = 'bd5e378503939ddaee76f12ad7a97608';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  /// Fetch weather data by city name
  Future<WeatherModel> getWeatherByCity(String cityName) async {
    if (cityName.trim().isEmpty) {
      throw WeatherException('Название города не может быть пустым');
    }

    final url = Uri.parse(
      '$_baseUrl?q=${Uri.encodeComponent(cityName)}&appid=$_apiKey&units=metric&lang=ru',
    );

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw WeatherException('Превышено время ожидания ответа от сервера');
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WeatherModel.fromJson(json);
      } else if (response.statusCode == 404) {
        throw WeatherException('Город "$cityName" не найден');
      } else if (response.statusCode == 401) {
        throw WeatherException('Ошибка авторизации API');
      } else {
        throw WeatherException('Ошибка сервера: ${response.statusCode}');
      }
    } on WeatherException {
      rethrow;
    } catch (e) {
      throw WeatherException('Не удалось подключиться к серверу погоды. Проверьте интернет-соединение.');
    }
  }

  /// Fetch weather data by coordinates (latitude and longitude)
  Future<WeatherModel> getWeatherByCoordinates(double latitude, double longitude) async {
    final url = Uri.parse(
      '$_baseUrl?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric&lang=ru',
    );

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw WeatherException('Превышено время ожидания ответа от сервера');
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WeatherModel.fromJson(json);
      } else {
        throw WeatherException('Ошибка получения погоды по координатам: ${response.statusCode}');
      }
    } on WeatherException {
      rethrow;
    } catch (e) {
      throw WeatherException('Не удалось подключиться к серверу погоды. Проверьте интернет-соединение.');
    }
  }
}
