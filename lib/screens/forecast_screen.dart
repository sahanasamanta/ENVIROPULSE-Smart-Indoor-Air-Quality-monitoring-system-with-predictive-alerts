import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  double temperature = 24;
  double humidity = 54.0;
  double aqi = 44;
  String quality = "Calculating...";

  Interpreter? interpreter;
  bool modelReady = false;
  bool dataFetched = false;

  @override
  void initState() {
    super.initState();
    initFirebase();
  }

  Future<void> initFirebase() async {
    try {
      await Firebase.initializeApp();
      await loadModel();
      setState(() {
        modelReady = true;
      });
    } catch (e) {
      debugPrint("[ERROR] Failed to initialize Firebase: $e");
    }
  }

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/model/nn_model.tflite');
      debugPrint("[INFO] TFLite model loaded.");
    } catch (e) {
      debugPrint("[ERROR] Failed to load TFLite model: $e");
    }
  }

  Future<void> fetchSensorData() async {
    try {
      final dbRef = FirebaseDatabase.instance.ref("iot_data");
      final snapshot = await dbRef.get();

      if (snapshot.exists) {
        final Map<String, dynamic> allData =
            Map<String, dynamic>.from(snapshot.value as Map);

        final latestEntry = allData.entries.toList()
          ..sort((a, b) => int.parse(b.key).compareTo(int.parse(a.key)));

        final latestData = Map<String, dynamic>.from(latestEntry.first.value);

        setState(() {
          temperature = (latestData['temperature'] as num).toDouble();
          humidity = (latestData['humidity'] as num).toDouble();
          aqi = (latestData['aqi'] as num).toDouble();
          dataFetched = true;
        });
        debugPrint("[DEBUG] Fetched data: temp=$temperature, humidity=$humidity, aqi=$aqi");
      } else {
        debugPrint("[WARN] No sensor data found in Firebase.");
      }
    } catch (e) {
      debugPrint("[ERROR] Failed to fetch sensor data: $e");
    }
  }

  Future<void> predictAirQuality() async {
    try {
      if (!modelReady || interpreter == null || !dataFetched) {
        debugPrint("[ERROR] Model not ready or data not fetched.");
        return;
      }

      // Replace with values from your scaler
      const double meanTemp = 30.74520338;
      const double meanHumidity = 68.76999233;
      const double meanAqi = 40.96392939;
      const double stdTemp = 5.35130739;
      const double stdHumidity = 9.30069014;
      const double stdAqi = 8.95393278;

      double standardizedTemp = (temperature - meanTemp) / stdTemp;
      double standardizedHumidity = (humidity - meanHumidity) / stdHumidity;
      double standardizedAqi = (aqi - meanAqi) / stdAqi;

      var input = [[standardizedTemp, standardizedHumidity, standardizedAqi]];
      var output = List.filled(1 * 3, 0.0).reshape([1, 3]);

      debugPrint("[DEBUG] Standardized input: $input");
      interpreter!.run(input, output);
      debugPrint("[DEBUG] Model output: $output");

      List<double> prediction = List<double>.from(output[0]);
      double maxValue = prediction.reduce((a, b) => a > b ? a : b);
      int maxIndex = prediction.indexOf(maxValue);

      String resultQuality = ["Good", "Moderate", "Unhealthy"][maxIndex];

      setState(() {
        quality = resultQuality;
      });

      if (quality == "Unhealthy") {
        sendEmailAlert();
      }
    } catch (e) {
      debugPrint("[ERROR] Failed to predict air quality: $e");
    }
  }

  void sendEmailAlert() async {
    final email = Uri(
      scheme: 'mailto',
      path: 'sahanasamanta31@gmail.com',
      query: Uri.encodeFull(
        'subject=Air Quality Alert&body=The air quality is unhealthy. Please take necessary precautions!',
      ),
    );
    if (await canLaunchUrl(email)) {
      await launchUrl(email);
    } else {
      debugPrint("[ERROR] Could not launch email");
    }
  }

  Widget buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget buildBlurButton({required String label, required VoidCallback onPressed}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg2.jpg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Indoor Sensor Data",
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Temperature: $temperature°C", style: const TextStyle(color: Colors.white)),
                        Text("Humidity: $humidity%", style: const TextStyle(color: Colors.white)),
                        Text("AQI: $aqi", style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Predicted Air Quality",
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  buildGlassCard(
                    child: Center(
                      child: Text(
                        quality,
                        style: TextStyle(
                          color: quality == "Unhealthy"
                              ? Colors.redAccent
                              : (quality == "Moderate"
                                  ? Colors.orangeAccent
                                  : Colors.greenAccent),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: buildBlurButton(
                      label: "🔍 Load & Predict",
                      onPressed: () async {
                        await fetchSensorData();
                        await predictAirQuality();
                      },
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    "If the air quality is unhealthy, an email will be triggered automatically.",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
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
