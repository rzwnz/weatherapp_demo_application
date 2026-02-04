import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../services/cache_service.dart';

/// Main weather screen widget
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();
  final CacheService _cacheService = CacheService();
  final TextEditingController _searchController = TextEditingController();

  WeatherModel? _weather;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showCacheNotification = false;

  @override
  void initState() {
    super.initState();
    _loadInitialWeather();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load initial weather data - try location first, then cached, then default city
  Future<void> _loadInitialWeather() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Try to get weather by current location first
      final hasLocationPermission = await _locationService.checkLocationPermission();
      if (hasLocationPermission) {
        await _getWeatherByLocation();
        return;
      }
    } catch (e) {
      // Location failed, continue to fallback
    }

    // Try to load last city from cache
    try {
      final lastCity = await _cacheService.getLastCity();
      if (lastCity != null) {
        await _searchWeather(lastCity);
        return;
      }
    } catch (e) {
      // Cache failed, continue to default
    }

    // Load default city (Moscow)
    await _searchWeather('Москва');
  }

  /// Search weather by city name
  Future<void> _searchWeather(String cityName) async {
    if (cityName.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showCacheNotification = false;
    });

    try {
      final weather = await _weatherService.getWeatherByCity(cityName);
      await _cacheService.cacheWeather(weather);
      
      setState(() {
        _weather = weather;
        _isLoading = false;
      });
    } on WeatherException catch (e) {
      // Try to load from cache
      await _tryLoadFromCache(e.message);
    } catch (e) {
      await _tryLoadFromCache('Произошла непредвиденная ошибка');
    }
  }

  /// Get weather by current location
  Future<void> _getWeatherByLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showCacheNotification = false;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      final weather = await _weatherService.getWeatherByCoordinates(
        position.latitude,
        position.longitude,
      );
      await _cacheService.cacheWeather(weather);
      
      setState(() {
        _weather = weather;
        _isLoading = false;
      });
    } on LocationException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
      _showErrorSnackBar(e.message);
    } on WeatherException catch (e) {
      await _tryLoadFromCache(e.message);
    } catch (e) {
      await _tryLoadFromCache('Не удалось получить данные о местоположении');
    }
  }

  /// Try to load weather from cache when API fails
  Future<void> _tryLoadFromCache(String originalError) async {
    final cachedWeather = await _cacheService.getCachedWeather();
    
    if (cachedWeather != null) {
      setState(() {
        _weather = cachedWeather;
        _isLoading = false;
        _showCacheNotification = true;
        _errorMessage = null;
      });
      _showCacheSnackBar();
    } else {
      setState(() {
        _errorMessage = originalError;
        _isLoading = false;
      });
      _showErrorSnackBar(originalError);
    }
  }

  /// Show error message in snackbar
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show cache notification in snackbar
  void _showCacheSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Не удалось обновить данные. Показаны данные из кэша.',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Handle search submission
  void _onSearchSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      _searchWeather(value.trim());
      _searchController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  /// Show search dialog
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Поиск города'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Введите название города',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) {
            Navigator.of(context).pop();
            _onSearchSubmitted(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _onSearchSubmitted(_searchController.text);
            },
            child: const Text('Найти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _getGradientColors(),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get gradient colors based on weather condition
  List<Color> _getGradientColors() {
    if (_weather == null) {
      return [Colors.blue.shade400, Colors.blue.shade900];
    }

    final condition = _weather!.mainCondition.toLowerCase();
    
    if (condition.contains('clear')) {
      return [Colors.orange.shade300, Colors.blue.shade600];
    } else if (condition.contains('cloud')) {
      return [Colors.blueGrey.shade300, Colors.blueGrey.shade700];
    } else if (condition.contains('rain') || condition.contains('drizzle')) {
      return [Colors.grey.shade400, Colors.blueGrey.shade800];
    } else if (condition.contains('thunder')) {
      return [Colors.deepPurple.shade400, Colors.grey.shade900];
    } else if (condition.contains('snow')) {
      return [Colors.lightBlue.shade100, Colors.blueGrey.shade400];
    } else if (condition.contains('mist') || condition.contains('fog') || condition.contains('haze')) {
      return [Colors.grey.shade300, Colors.grey.shade600];
    }
    
    return [Colors.blue.shade400, Colors.blue.shade900];
  }

  /// Build custom app bar
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white, size: 28),
            onPressed: _isLoading ? null : _getWeatherByLocation,
            tooltip: 'Моё местоположение',
          ),
          const Text(
            'Погода',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 28),
            onPressed: _isLoading ? null : _showSearchDialog,
            tooltip: 'Поиск города',
          ),
        ],
      ),
    );
  }

  /// Build main body content
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Загрузка...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _weather == null) {
      return _buildErrorWidget();
    }

    if (_weather == null) {
      return const Center(
        child: Text(
          'Нет данных о погоде',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _searchWeather(_weather!.cityName),
      color: Colors.white,
      backgroundColor: Colors.blue.shade700,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_showCacheNotification) _buildCacheNotification(),
            _buildCityName(),
            _buildWeatherIcon(),
            _buildTemperature(),
            _buildDescription(),
            const SizedBox(height: 32),
            _buildDetailsCard(),
          ],
        ),
      ),
    );
  }

  /// Build cache notification banner
  Widget _buildCacheNotification() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade700.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.offline_bolt, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Данные загружены из кэша. Потяните вниз для обновления.',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Build error widget
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 80,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInitialWeather,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build city name widget
  Widget _buildCityName() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_on, color: Colors.white, size: 28),
        const SizedBox(width: 8),
        Text(
          _weather!.cityName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Build weather icon widget
  Widget _buildWeatherIcon() {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Image.network(
        _weather!.iconUrl,
        width: 150,
        height: 150,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            _getWeatherIconData(_weather!.mainCondition),
            size: 100,
            color: Colors.white,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      ),
    );
  }

  /// Get fallback icon based on weather condition
  IconData _getWeatherIconData(String condition) {
    final lowerCondition = condition.toLowerCase();
    
    if (lowerCondition.contains('clear')) {
      return Icons.wb_sunny;
    } else if (lowerCondition.contains('cloud')) {
      return Icons.cloud;
    } else if (lowerCondition.contains('rain') || lowerCondition.contains('drizzle')) {
      return Icons.grain;
    } else if (lowerCondition.contains('thunder')) {
      return Icons.flash_on;
    } else if (lowerCondition.contains('snow')) {
      return Icons.ac_unit;
    } else if (lowerCondition.contains('mist') || lowerCondition.contains('fog')) {
      return Icons.blur_on;
    }
    
    return Icons.wb_cloudy;
  }

  /// Build temperature widget
  Widget _buildTemperature() {
    return Text(
      _weather!.temperatureString,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 72,
        fontWeight: FontWeight.w200,
      ),
    );
  }

  /// Build weather description widget
  Widget _buildDescription() {
    return Text(
      _weather!.capitalizedDescription,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: 24,
      ),
    );
  }

  /// Build details card widget
  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            Icons.thermostat,
            'Ощущается как',
            _weather!.feelsLikeString,
          ),
          const Divider(color: Colors.white30, height: 24),
          _buildDetailRow(
            Icons.water_drop,
            'Влажность',
            _weather!.humidityString,
          ),
          const Divider(color: Colors.white30, height: 24),
          _buildDetailRow(
            Icons.air,
            'Ветер',
            _weather!.windSpeedString,
          ),
        ],
      ),
    );
  }

  /// Build detail row widget
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
