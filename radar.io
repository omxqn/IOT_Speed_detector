#include <WiFi.h>
#include <WebServer.h>
#include <DFRobotDFPlayerMini.h>
#include <HardwareSerial.h>

#define RADAR_PIN 34      // ADC pin connected to HB100 IF output
#define SAMPLE_RATE 2000  // Hz
#define N_SAMPLES 1000    // ~0.5 s window
#define RELAY_PIN 25      // GPIO pin connected to relay module

float samples[N_SAMPLES];
bool relayActive = false;
unsigned long relayStartTime = 0;
const unsigned long RELAY_DURATION = 7000;  // Relay active time in ms
const float SPEED_THRESHOLD = 20;           // km/h threshold to trigger relay

// ===== DFPlayer Mini Setup =====
HardwareSerial mySerial(1);  // use UART1 for DFPlayer
DFRobotDFPlayerMini myDFPlayer;

bool soundActive = false;
unsigned long lastPlayTime = 0;

// ===== WiFi Config =====
const char* ssid = "ESP32-Speed";
const char* password = "12345678";  // hotspot password
WebServer server(80);

float speed_kmh = 0.0;

// ===== Web Page =====
String getHTML() {
  String html = "<!DOCTYPE html><html lang='en'><head>";
  html += "<meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<meta http-equiv='refresh' content='1'>";
  html += "<title>ESP32 Car Speed Meter</title>";
  html += "<style>";
  html += "body{margin:0;font-family:Inter,Arial,sans-serif;background:linear-gradient(180deg,#0f1724,#071025);color:#e6eef8;text-align:center}";
  html += ".card{max-width:500px;margin:40px auto;padding:24px;background:rgba(255,255,255,0.04);backdrop-filter:blur(6px);border-radius:16px;box-shadow:0 8px 24px rgba(0,0,0,0.6)}";
  html += "h1{margin:0;font-size:22px;background:linear-gradient(135deg,#00d4ff,#7b61ff);-webkit-background-clip:text;-webkit-text-fill-color:transparent}";
  html += ".status{margin:18px 0;font-size:18px;color:#cbd5e1}";
  html += ".value{display:block;font-size:32px;font-weight:700;margin-top:6px;color:transparent;background:linear-gradient(135deg,#00d4ff,#7b61ff);-webkit-background-clip:text;-webkit-text-fill-color:transparent}";
  html += ".btn{display:inline-block;padding:12px 20px;margin:8px;border-radius:12px;font-weight:700;border:0;cursor:pointer;text-decoration:none}";
  html += ".btn.primary{background:linear-gradient(135deg,#00d4ff,#7b61ff);color:#041226}";
  html += ".btn.stop{background:rgba(255,255,255,0.06);color:#94a3b8}";
  html += "footer{margin-top:20px;font-size:13px;color:#94a3b8}";
  html += "</style></head><body>";
  html += "<div class='card'>";
  html += "<h1>🚗 ESP32 Car Speed Meter</h1>";
  html += "<div class='status'>Speed:<span class='value'>" + String(speed_kmh, 1) + " km/h</span></div>";
  html += "<div class='status'>Relay:<span class='value'>" + String(relayActive ? "ON" : "OFF") + "</span></div>";
  html += "<div class='status'>Sound:<span class='value'>" + String(soundActive ? "PLAYING" : "STOPPED") + "</span></div>";
  html += "<form action='/trigger'><button class='btn primary' type='submit'>Trigger</button></form>";
  html += "<form action='/stop'><button class='btn stop' type='submit'>Stop</button></form>";
  html += "<footer>Auto-refresh every 1s • Powered by ESP32</footer>";
  html += "</div></body></html>";
  return html;
}


void handleRoot() {
  server.send(200, "text/html", getHTML());
}

// ===== Trigger / Stop Functions =====
void triggerSystem() {
  digitalWrite(RELAY_PIN, HIGH);
  relayActive = true;
  relayStartTime = millis();
  soundActive = true;
  lastPlayTime = 0;  // force immediate play
  Serial.println("Relay + Sound Triggered");
}

void stopSystem() {
  digitalWrite(RELAY_PIN, LOW);
  relayActive = false;
  soundActive = false;
  myDFPlayer.stop();
  Serial.println("Relay + Sound Stopped");
}

// ===== Web Handlers =====
void handleTrigger() {
  triggerSystem();
  server.sendHeader("Location", "/");  // redirect back to main page
  server.send(303);
}

void handleStop() {
  stopSystem();
  server.sendHeader("Location", "/");  // redirect back to main page
  server.send(303);
}

void setup() {
  Serial.begin(115200);

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);  // Relay off initially
  Serial.println("Car Speed Meter Ready");

  // Start serial for DFPlayer (RX=16, TX=17)
  mySerial.begin(9600, SERIAL_8N1, 16, 17);

  if (!myDFPlayer.begin(mySerial)) {
    Serial.println("DFPlayer Mini not found!");
    while (true)
      ;
  }
  Serial.println("DFPlayer Mini online.");
  myDFPlayer.volume(30);  // set volume (0–30)

  // Start WiFi in AP mode
  WiFi.softAP(ssid, password);
  Serial.println("WiFi AP started");
  Serial.print("IP: ");
  Serial.println(WiFi.softAPIP());

  // Setup web server
  server.on("/", handleRoot);
  server.on("/trigger", handleTrigger);
  server.on("/stop", handleStop);
  server.begin();
}

void loop() {
  server.handleClient();

  // ==== Serial Command Check ====
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toUpperCase();

    if (cmd == "TRIGGER" || cmd == "T") {
      triggerSystem();
    } else if (cmd == "STOP" || cmd == "S") {
      stopSystem();
    }
  }

  // ==== Radar Processing ====
  for (int i = 0; i < N_SAMPLES; i++) {
    samples[i] = analogRead(RADAR_PIN);
    delayMicroseconds(1000000 / SAMPLE_RATE);
  }

  // Zero-crossing frequency estimation
  int crossings = 0;
  for (int i = 1; i < N_SAMPLES; i++) {
    if ((samples[i - 1] < 2048 && samples[i] >= 2048) || (samples[i - 1] > 2048 && samples[i] <= 2048)) {
      crossings++;
    }
  }

  float freq = (crossings * (SAMPLE_RATE / (float)N_SAMPLES)) / 2.0;
  float lambda = 0.03125;                  // Radar wavelength in meters
  float velocity = (freq * lambda) / 2.0;  // m/s

  // Convert to km/h
  speed_kmh = velocity * 3.6;
  if (speed_kmh < 1) speed_kmh = 0;  // ignore noise

  Serial.print("Car Speed: ");
  Serial.print(speed_kmh, 1);
  Serial.println(" km/h");

  // Trigger from radar
  if (speed_kmh >= SPEED_THRESHOLD && !relayActive) {
    triggerSystem();
  }

  // If relay is active, handle sound replay
  if (relayActive) {
    // keep restarting sound every time it ends
    if (millis() - lastPlayTime > 400) {  // replay every ~0.7s
      myDFPlayer.play(1);                 // play "0001.mp3"
      lastPlayTime = millis();
    }

    // Stop after duration
    if (millis() - relayStartTime >= RELAY_DURATION) {
      stopSystem();
    }
  }

  delay(100);  // short delay
}
