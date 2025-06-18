import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // ✅ Import geocoding

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String city = "";
  Map<String, dynamic>? weatherData;
  final TextEditingController cityController = TextEditingController();

  final String apiKey = '80b54e95678cc8db79f1bcb7248bbd96'; // 🔁 Add your OpenWeatherMap API key here

  @override
  void initState() {
    super.initState();
    fetchWeatherByLocation();
  }

  Future<void> fetchWeatherByLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission permanently denied')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    fetchWeatherByCoordinates(position.latitude, position.longitude);
  }

  Future<void> fetchWeatherByCoordinates(double lat, double lon) async {
    try {
      // ✅ Reverse Geocode to get full location name
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      String locationName = '';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        locationName =
            '${p.locality ?? ''}, ${p.administrativeArea ?? ''}, ${p.country ?? ''}';
      }

      if (apiKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key is missing')),
        );
        return;
      }

      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          weatherData = json.decode(response.body);
          city = locationName.isNotEmpty
              ? locationName
              : weatherData!['name']; // fallback if reverse geocoding fails
        });
      } else {
        debugPrint('Error fetching weather data: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch weather data')),
        );
      }
    } catch (e) {
      debugPrint('Error fetching location or weather: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch location/weather')),
      );
    }
  }

  Future<void> fetchWeather(String cityName) async {
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key is missing')),
      );
      return;
    }

    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=$cityName&appid=$apiKey&units=metric',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      setState(() {
        weatherData = json.decode(response.body);
        city = cityName;
      });
    } else {
      debugPrint('Error fetching weather data for city: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('City not found!')),
      );
    }
  }

  IconData getWeatherIcon(String condition) {
    condition = condition.toLowerCase();
    if (condition.contains("rain")) return Icons.water_drop;
    if (condition.contains("cloud")) return Icons.cloud;
    if (condition.contains("clear")) return Icons.wb_sunny;
    return Icons.cloud_queue;
  }

  Widget getDayNightIcon(int timestamp, int timezoneOffset) {
    final utc =
        DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
    final local = utc.add(Duration(seconds: timezoneOffset));
    return Icon(
      (local.hour >= 6 && local.hour < 18)
          ? Icons.wb_sunny
          : Icons.nightlight_round,
      color: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg1.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black.withOpacity(0.4),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🔍 Search Bar
                  TextField(
                    controller: cityController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter city name',
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () {
                          if (cityController.text.isNotEmpty) {
                            fetchWeather(cityController.text);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  /// 🌤️ Weather Info
                  if (weatherData != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              getWeatherIcon(
                                weatherData!['weather'][0]['main'],
                              ),
                              size: 48,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "${weatherData!['main']['temp']}°C",
                              style: const TextStyle(
                                fontSize: 40,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            getDayNightIcon(
                              weatherData!['dt'],
                              weatherData!['timezone'],
                            ),
                          ],
                        ),
                        Text(
                          weatherData!['weather'][0]['main'],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              city,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.water_drop, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              "Humidity: ${weatherData!['main']['humidity']}%",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.air, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              "Wind: ${weatherData!['wind']['speed']} m/s",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),

                  const Spacer(),

                  /// 🔘 Forecast Button
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/forecast');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 140, 186, 190).withOpacity(0.08),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "Show Predicted Forecast",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}