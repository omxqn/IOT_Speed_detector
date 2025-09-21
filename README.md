# 🚗 ESP32 Car Speed Meter

An ESP32-based **car speed detection system** using an **HB100 Doppler radar**, **relay control**, and **DFPlayer Mini audio module**, all wrapped with a **Wi-Fi web dashboard** and serial command support.

![ESP32](https://img.shields.io/badge/ESP32-Powered-blue?logo=espressif)  
![Arduino](https://img.shields.io/badge/Arduino-IDE-green?logo=arduino)  
![License](https://img.shields.io/badge/License-MIT-yellow)

---

## ✨ Features

- 📡 **Speed Measurement**  
  - Detects vehicle speed using HB100 radar  
  - Calculates speed in **km/h** via zero-crossing frequency estimation  

- ⚡ **Relay Control**  
  - Automatically triggers a relay if speed exceeds a configurable threshold  
  - Manual **Trigger/Stop** control via web or serial  

- 🔊 **Audio Alerts**  
  - Plays MP3 warning sound via DFPlayer Mini when speed exceeds threshold  
  - Auto-replays while relay is active  

- 🌐 **Web Dashboard**  
  - Runs a Wi-Fi **Access Point** (SSID: `ESP32-Speed`)  
  - Live status view with **auto-refresh** every 1s  
  - Interactive buttons: `Trigger` and `Stop`  
  - Accessible via **http://192.168.4.1** 🌍
  - 
- 🖥 **Serial Command Control**  
  - `TRIGGER` / `T` → activate relay + sound  
  - `STOP` / `S` → stop relay + sound  

---

## 📸 Web Dashboard Preview


Styled with a **glassmorphic card UI** + gradient accents 🎨.

---

## 🛠 Hardware Requirements

- **ESP32 Development Board**  
- **HB100 Doppler Radar Module** (connected to ADC pin `34`)  
- **DFPlayer Mini + Speaker** (connected via UART1: RX=16, TX=17)  
- **Relay Module** (connected to GPIO `25`)  
- Power supply (5V recommended)

---

## ⚙️ Configuration

| Parameter           | Default     | Description                           |
|---------------------|-------------|---------------------------------------|
| `SAMPLE_RATE`       | 2000 Hz     | Radar sampling frequency              |
| `N_SAMPLES`         | 1000        | Samples per window (~0.5s)            |
| `SPEED_THRESHOLD`   | 20 km/h     | Relay/sound trigger speed             |
| `RELAY_DURATION`    | 7000 ms     | Relay active duration before auto-off |
| Wi-Fi SSID          | ESP32-Speed | Hotspot SSID                          |
| Wi-Fi Password      | 12345678    | Hotspot password                      |

---

## 🚀 Getting Started

1. Clone this repo  
   ```bash
   git clone https://github.com/your-username/esp32-car-speed-meter.git
   cd esp32-car-speed-meter
