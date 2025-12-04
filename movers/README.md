🚚 Movers App

A cross-platform mobile application built with Flutter, featuring real-time data, authentication, and geolocation capabilities.

--------------------------------------------------------------------------------------------------------------

Overview
--------
Movers is designed to be a fully functional, production-ready mobile application.
It leverages powerful Flutter plugins and Firebase services to support:

🔐 User authentication

📡 Real-time NoSQL data storage and retrieval

📍 Device geolocation tracking

🗺️ Mapping with OpenStreetMap

🌐 External REST API communication

⚙️ Setup & Dependencies

All required dependencies have been fully installed and configured.

--------------------------------------------------------------------------------------------------------------

Key Dependency Breakdown
------------------------
Category	Package Name	Purpose
Firebase Core	firebase_core	Connects the Flutter app to Firebase backend
Database	cloud_firestore	Handles real-time NoSQL database operations (store & retrieve data)
Authentication	firebase_auth	Manages user sign-up and sign-in
Geolocation	geolocator	Retrieves the device’s current location
Mapping	OpenStreetMap (via Flutter OSM packages)	Provides map display and interaction
Network	http	Enables external REST API calls

--------------------------------------------------------------------------------------------------------------

Project Goal
------------
To deliver a seamless and modern mobile experience by integrating:

Real-time Firebase-powered data flow

Secure and scalable user authentication

Accurate and efficient location-based features

Interactive, customizable map interfaces

--------------------------------------------------------------------------------------------------------------

 Getting Started
----------------
Clone the repository:

git clone https://github.com/PrimeTony/Movers.git
cd movers

--------------------------------------------------------------------------------------------------------------

Install dependencies:
--------------------
flutter pub get


Run the app:

flutter run

--------------------------------------------------------------------------------------------------------------

Notes
-----
Make sure Firebase is properly configured for your iOS and Android builds (Google Services files required).
