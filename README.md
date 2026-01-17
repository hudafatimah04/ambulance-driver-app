# 🚑 Ambulance Driver App

A real-time **ambulance driver module** built as part of an **AI-based Emergency Response System**.  
This app focuses entirely on the **driver workflow**, from receiving emergencies to transporting patients to hospitals.

---

## 📱 Features

- 🚨 Real-time emergency request handling  
- 🧭 Live ambulance GPS tracking (simulated movement)  
- 🗺️ Route visualization using OpenStreetMap  
- 🔄 Supabase Realtime database integration  
- 🏥 Hospital confirmation workflow  
- 📊 Trip completion summary  
- 🧩 State-based UI (Idle → Pickup → Hospital → Completed)

---

## 🧑‍💻 Project Scope

This repository contains **only the Driver-side application**.

Other system components are **out of scope** for this repository:

- Victim app  
- Hospital dashboard  
- AI hospital / ambulance allocation logic  

These components are handled independently.

---

## 🛠️ Tech Stack

- Flutter (Material 3)  
- Supabase (PostgreSQL + Realtime)  
- Flutter Map (OpenStreetMap)  
- Geolocator  
- OSRM Routing API  

---

## 🔐 Environment Configuration

Supabase credentials are **intentionally excluded** from version control.

Create the following file locally:

    lib/config/supabase_config.dart

Refer to the example file provided in the repository:

    lib/config/supabase_config.example.dart

---

## 🚀 Running the App Locally

    flutter pub get
    flutter run

---

## 📦 APK Download (Demo)

A demo APK build is available under **GitHub Releases**:

👉 https://github.com/hudafatimah04/ambulance-driver-app/releases

> ⚠️ This APK is for **demonstration and academic use only**.  
> It is **not Play Store ready**.

---

## 👤 Author

**Huda Fatimah**  
Ambulance Driver Module – AI Emergency Response System

---

## 📄 License

This project is developed for **academic and demonstration purposes**.
