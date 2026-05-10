# Disaster-Sense

**Disaster prediction and early warning system for Pakistan.**

Disaster-Sense is a comprehensive mobile application and backend service designed to monitor, predict, and alert users about various natural disasters such as floods, earthquakes, and heatwaves. Built with Flutter for the frontend and FastAPI for the backend, it provides real-time situational awareness and AI-powered actionable advice to help people stay safe during critical events.

## 🌟 Features

- **Real-Time Monitoring:** Continuous monitoring of weather patterns, geological activity, and environmental factors across major cities in Pakistan.
- **Multilingual AI Advisor:** An intelligent, context-aware chatbot (powered by LLMs like Google Generative AI, Groq, and OpenAI) that provides localized risk summaries and advice in English, Roman Urdu, and Urdu.
- **Push Notifications & Background Services:** Hardened notification system that runs periodic background checks. It fires granular, category-specific alerts (e.g., Flood, Heatwave, Earthquake) directly to your device. Tap any alert to navigate instantly to the relevant city detail screen.
- **Interactive Maps:** Real-time visual representation of disaster risks on a map with color-coded, icon-based markers.
- **Location-Aware:** Intelligent tracking to find the nearest disasters and evaluate risks based on the user's specific location.
- **Preparedness Guides & History:** Built-in guides for disaster preparedness and a full history of past alerts.

## 🏗️ Architecture

### Frontend (Mobile App)
- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Key Libraries:** `flutter_map`, `geolocator`, `flutter_local_notifications`, `workmanager`, `fl_chart`
- **Features:** Dynamic UI with light/dark modes, material 3 design, background tasks, and local notifications.

### Backend (API Engine)
- **Framework:** FastAPI (Python)
- **Database:** SQLAlchemy (MySQL)
- **Task Scheduling:** APScheduler for periodic data fetching
- **Integration:** Resilient LLM fallback system for the AI advisor.

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Python 3.9+](https://www.python.org/downloads/)
- MySQL Database

### Backend Setup
1. Navigate to the `backend` directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Configure your environment variables in `.env` (Database URL, API Keys for LLM providers).
4. Run the FastAPI server:
   ```bash
   uvicorn main:app --reload
   ```

### Frontend Setup
1. From the project root, get Flutter packages:
   ```bash
   flutter pub get
   ```
2. Run the application on your connected device or emulator:
   ```bash
   flutter run
   ```

## 🤝 Contributing

Contributions are welcome! If you'd like to improve the prediction models, enhance the UI, or add new local languages for the AI advisor, feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.
