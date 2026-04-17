import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final String cityName;
  final double temperature;
  final String description;
  final String mainWeather;

  WeatherData({
    required this.cityName,
    required this.temperature,
    required this.description,
    required this.mainWeather,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      cityName: json['name'] ?? '-',
      temperature: (json['main']['temp'] as num).toDouble(),
      description: json['weather'][0]['description'] ?? '-',
      mainWeather: json['weather'][0]['main'] ?? '-',
    );
  }
}

class ForecastData {
  final DateTime dateTime;
  final double temperature;
  final String description;
  final String mainWeather;

  ForecastData({
    required this.dateTime,
    required this.temperature,
    required this.description,
    required this.mainWeather,
  });

  factory ForecastData.fromJson(Map<String, dynamic> json) {
    return ForecastData(
      dateTime: DateTime.parse(json['dt_txt']),
      temperature: (json['main']['temp'] as num).toDouble(),
      description: json['weather'][0]['description'] ?? '-',
      mainWeather: json['weather'][0]['main'] ?? '-',
    );
  }
}

class WeatherResult {
  final WeatherData current;
  final List<ForecastData> next3Days;

  WeatherResult({
    required this.current,
    required this.next3Days,
  });
}

class WeatherService {
  static const String _apiKey =
      '0ac1d5763cb4df6930a558e774fdf09a'; // Ganti dengan API key OpenWeather
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';
  static const String _forecastUrl =
      'https://api.openweathermap.org/data/2.5/forecast';

  Future<WeatherData> getCurrentWeather({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=id',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return WeatherData.fromJson(data);
    } else {
      throw Exception('Failed to load weather');
    }
  }

  Future<List<ForecastData>> get3DayForecast({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse(
      '$_forecastUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=id',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load forecast');
    }

    final data = jsonDecode(response.body);
    final List list = data['list'];

    return list.map((item) => ForecastData.fromJson(item)).toList();
  }

  Future<WeatherResult> getWeatherByAddress(String address) async {
    final location = await getCoordinatesFromAddress(address);
    final current =
        await getCurrentWeather(lat: location.lat, lon: location.lon);
    final forecast =
        await get3DayForecast(lat: location.lat, lon: location.lon);

    return WeatherResult(
      current: current,
      next3Days: forecast,
    );
  }

  Future<LocationResult> getCoordinatesFromAddress(String address) async {
    final uri = Uri.parse(
      'https://api.openweathermap.org/geo/1.0/direct?q=$address&limit=1&appid=$_apiKey',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load coordinates');
    }

    final data = jsonDecode(response.body);
    if (data is! List || data.isEmpty) {
      throw Exception('Address not found');
    }

    return LocationResult.fromJson(data[0]);
  }
}

class LocationResult {
  final double lat;
  final double lon;

  LocationResult({
    required this.lat,
    required this.lon,
  });

  factory LocationResult.fromJson(Map<String, dynamic> json) {
    return LocationResult(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );
  }
}
