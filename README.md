# Nutrition Scanner

An AI-powered mobile application that helps users make informed dietary decisions by analyzing food products through image recognition. The application scans a food item, extracts relevant information from its packaging, and provides nutritional insights, ingredient analysis, health recommendations, and personalized dietary guidance.

---

## Overview

Nutrition Scanner is a Flutter-based mobile application that leverages Barcodes and OpenFoodFacts API to identify food products and analyze their nutritional content. The application is designed to simplify nutrition tracking by allowing users to scan food packaging instead of manually entering nutritional information.

The system processes captured images, extracts text from nutrition labels, interprets the nutritional values using Algorithms, and presents users with easy-to-understand health insights.

---

## Features

* Capture food packaging using the device camera
* Select images from the gallery
* Optical Character Recognition (OCR) for nutrition label extraction
* Algorithm-powered nutritional analysis
* Ingredient interpretation and explanation
* Healthiness assessment of food products
* Identification of potentially harmful ingredients
* Personalized dietary recommendations
* Clean and intuitive user interface

---

## Technology Stack

### Frontend

* Flutter
* Dart

### Development Tools

* Android Studio
* Visual Studio Code
* Git
* GitHub

---

## Project Structure

```
nutrition-scanner/
│
├── android/
├── lib/
│   ├── screens/
│   ├── widgets/
│   ├── services/
│   ├── models/
│   ├── utils/
│   └── main.dart
│
├── assets/
│   ├── images/
│   └── icons/
│
├── pubspec.yaml
└── README.md
```

---

## Getting Started

### Prerequisites

Before running the project, ensure the following are installed:

* Flutter SDK
* Dart SDK
* Git
* Android Studio or Visual Studio Code
* Android Emulator or Physical Android Device

---

## Installation

### Clone the Repository

```bash
git clone https://github.com/your-username/nutrition-scanner.git
cd nutrition-scanner
```

### Install Flutter Dependencies

```bash
flutter pub get
```
---

## Running the Application

### Run Flutter

```bash
flutter run
```

---

##  How It Works

1. Launch the application.
2. Capture barcode of a food product.
3. The application extracts barcode number.
4. The application checks against local database.
5. If it doesn't not exists, it uses openfoodfacts api.
6. It performs ingredient and nutrient analysis.
7. A comprehensive nutrition report is generated and displayed.

---

## Project Objectives

* Simplify nutrition label interpretation.
* Promote healthier eating habits.
* Reduce manual nutrition tracking.
* Improve awareness of food ingredients and nutritional values.
