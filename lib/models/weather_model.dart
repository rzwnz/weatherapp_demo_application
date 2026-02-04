/// Model class representing weather data
class WeatherModel {
  final String cityName;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final String description;
  final String icon;
  final String mainCondition;
  final DateTime timestamp;
  final bool isFromCache;

  WeatherModel({
    required this.cityName,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.description,
    required this.icon,
    required this.mainCondition,
    required this.timestamp,
    this.isFromCache = false,
  });

  /// Create WeatherModel from OpenWeatherMap API JSON response
  factory WeatherModel.fromJson(Map<String, dynamic> json, {bool isFromCache = false}) {
    return WeatherModel(
      cityName: json['name'] ?? 'Unknown',
      temperature: (json['main']['temp'] as num).toDouble(),
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      humidity: json['main']['humidity'] as int,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      description: json['weather'][0]['description'] ?? '',
      icon: json['weather'][0]['icon'] ?? '01d',
      mainCondition: json['weather'][0]['main'] ?? '',
      timestamp: DateTime.now(),
      isFromCache: isFromCache,
    );
  }

  /// Convert WeatherModel to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'name': cityName,
      'main': {
        'temp': temperature,
        'feels_like': feelsLike,
        'humidity': humidity,
      },
      'wind': {
        'speed': windSpeed,
      },
      'weather': [
        {
          'description': description,
          'icon': icon,
          'main': mainCondition,
        }
      ],
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Get weather icon URL from OpenWeatherMap
  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@4x.png';

  /// Get formatted temperature string
  String get temperatureString => '${temperature.round()}°C';

  /// Get formatted feels like temperature string
  String get feelsLikeString => '${feelsLike.round()}°C';

  /// Get formatted wind speed string
  String get windSpeedString => '${windSpeed.toStringAsFixed(1)} м/с';

  /// Get formatted humidity string
  String get humidityString => '$humidity%';

  /// Get capitalized description
  String get capitalizedDescription {
    if (description.isEmpty) return '';
    return description[0].toUpperCase() + description.substring(1);
  }
}
