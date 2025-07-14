#include <WiFi.h>
#include <FirebaseESP32.h>
#include <DHT.h>
#include <time.h>  

// === Sensor Pins ===
#define DHTPIN 4
#define DHTTYPE DHT11
#define MQ135_PIN 34  // Analog input pin for MQ135

const char* ssid = "WIFISSID";
const char* password = "PASSWORD";  //Add your password here

#define FIREBASE_HOST "FIREBASE_HOST"  
#define FIREBASE_AUTH "DATABASE_SECRET"  //Add your Database Secret here

FirebaseData firebaseData;
FirebaseAuth auth;
FirebaseConfig config;

#define BUZZER_PIN 17
DHT dht(DHTPIN, DHTTYPE);

// === Time Sync ===
void syncTime() {
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  Serial.print("⏳ Syncing NTP time");
  
  int attempts = 0;
  while (time(nullptr) < 100000 && attempts < 20) {  // Wait max ~10 seconds
    Serial.print(".");
    delay(500);
    attempts++;
  }

  if (time(nullptr) >= 100000) {
    Serial.println("\n✅ Time synced!");
    time_t now = time(nullptr);
    Serial.print("🕒 Current time: ");
    Serial.println(ctime(&now));
  } else {
    Serial.println("\n❌ Time sync failed!");
  }
}

void setup() {
  Serial.begin(115200);
  dht.begin();
  delay(5000);  // Allow sensors to stabilize

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  Serial.println("🌿 Indoor Air Quality Monitoring System Initialized");

  // === Connect to Wi-Fi ===
  Serial.print("Connecting to Wi-Fi");
  WiFi.begin(ssid, password);

  int wifiTries = 0;
  while (WiFi.status() != WL_CONNECTED && wifiTries < 30) {
    delay(500);
    Serial.print(".");
    wifiTries++;
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\n❌ Failed to connect to Wi-Fi");
    return;
  }

  Serial.println("\n✅ Wi-Fi connected!");

  // === Sync NTP time ===
  syncTime();

  // === Firebase setup ===
  config.host = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();

  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("❌ Failed to read from DHT11 sensor!");
    return;
  }

  Serial.print("🌡 Temperature: ");
  Serial.print(temperature);
  Serial.print(" °C, 💧 Humidity: ");
  Serial.print(humidity);
  Serial.println(" %");

  int mq135_adc = analogRead(MQ135_PIN);
  //Serial.print("Raw MQ135 ADC: ");
  //Serial.println(mq135_adc);

  float aqi = ((float)(mq135_adc - 200) / (3000 - 200)) * 500;
  aqi = constrain(aqi, 0, 500);
  Serial.print("Estimated AQI: ");
  Serial.println(aqi);

  // === Alerting system ===
  digitalWrite(BUZZER_PIN, LOW);

  if (aqi <= 50) {
    Serial.println("✅ AQI: Good (Green)");
  } else if (aqi <= 100) {
    Serial.println("⚠ AQI: Moderate (Yellow)");
  } else {
    Serial.println("❌ AQI: Unhealthy (Red)");
    tone(BUZZER_PIN, 1000);
    delay(2000);
    noTone(BUZZER_PIN);
  }

  if (temperature < 15 || temperature > 35) {
    Serial.println("⚠ Temperature Alert!");
  }

  if (humidity < 30 || humidity > 70) {
    Serial.println("⚠ Humidity Alert!");
  }

  // === Log data ===
  Serial.print("DATA:TEMP:");
  Serial.print(temperature);
  Serial.print(",HUM:");
  Serial.print(humidity);
  Serial.print(",AQI:");
  Serial.println(aqi);

  // === Upload to Firebase with NTP timestamp ===
  time_t now = time(nullptr);
  String path = "/iot_data/" + String(now);

  bool success1 = Firebase.setFloat(firebaseData, path + "/temperature", temperature);
  bool success2 = Firebase.setFloat(firebaseData, path + "/humidity", humidity);
  bool success3 = Firebase.setFloat(firebaseData, path + "/aqi", aqi);

  if (success1 && success2 && success3) {
    Serial.println("✅ Data uploaded to Firebase");
  } else {
    Serial.print("❌ Firebase upload failed: ");
    Serial.println(firebaseData.errorReason());
  }

  Serial.println("--------------------------");
  delay(5000);  // Repeat every 5 seconds
}
