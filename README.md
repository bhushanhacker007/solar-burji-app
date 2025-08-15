# ☀️ Solar Burji Business Management App

A comprehensive cross-platform business management application for solar panel sales, customer borrowings, and solar power monitoring. Built with Flutter for the frontend and PHP for the backend.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=for-the-badge&logo=php&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-00000F?style=for-the-badge&logo=mysql&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

## 📱 Features

### 🏪 Sales Management
- Track daily sales transactions
- Separate cash and online payments
- Add notes to transactions
- View sales analytics and charts
- Export sales reports to PDF
- Real-time data updates with cache-busting

### 💰 Borrowings & Repayments
- Record customer borrowings
- Track repayments
- View net borrowing status
- Customer-wise transaction history
- Export borrowing reports
- Interactive charts and trends

### ☀️ Solar Power Monitoring
- Daily solar power readings
- Import/Export/Generation tracking
- Power consumption analytics
- Historical data visualization
- Export solar reports
- Power trend analysis

### 📊 Analytics & Reports
- Interactive charts and graphs
- Daily, weekly, monthly views
- PDF report generation
- Real-time data updates
- Pull-to-refresh functionality
- Responsive design for all devices

## 🏗️ Architecture

```
solar_burji_app/
├── frontend/                 # Flutter application
│   └── solar_burji_frontend/
│       ├── lib/
│       │   ├── src/
│       │   │   ├── api_client.dart    # HTTP client with cache-busting
│       │   │   ├── screens/           # UI screens
│       │   │   ├── models/            # Data models
│       │   │   ├── ui/                # Reusable components
│       │   │   └── pdf/               # PDF export functionality
│       │   └── main.dart
│       └── android/                   # Android-specific config
├── backend/                  # PHP REST API
│   ├── api/
│   │   ├── sales.php         # Sales endpoints
│   │   ├── borrowings.php    # Borrowings endpoints
│   │   ├── solar.php         # Solar data endpoints
│   │   └── helpers.php       # Utility functions
│   ├── config/
│   │   ├── config.php        # Configuration
│   │   └── db.php           # Database connection
│   └── sql/
│       └── schema.sql       # Database schema
└── demo_package/            # Production-ready demo files
    ├── web_app/             # Deployable web version
    ├── solar_burji_app_fixed.apk  # Android APK
    └── Documentation files
```

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.8.1+)
- PHP 7.4+
- MySQL 5.7+
- Android Studio / VS Code

### Frontend Setup
```bash
cd frontend/solar_burji_frontend
flutter pub get
flutter run
```

### Backend Setup
```bash
cd backend
# Configure database in config/db.php
# Import schema.sql to MySQL
# Set up web server (Apache/Nginx)
```

### Configuration
Update `frontend/solar_burji_frontend/lib/src/config.dart`:
```dart
class AppConfig {
  static const String apiBaseUrl = 'https://your-domain.com/backend/api';
  static const String apiKey = 'your-api-key';
}
```

## 📱 Platform Support

- ✅ **Web** - Progressive Web App
- ✅ **Android** - Native APK
- ✅ **iOS** - Native App (requires Apple Developer account)
- ✅ **Desktop** - Windows, macOS, Linux

## 🔧 Technical Stack

### Frontend
- **Framework**: Flutter 3.8.1
- **Language**: Dart
- **State Management**: setState
- **HTTP Client**: http package with cache-busting
- **Charts**: FL Chart
- **PDF Export**: pdf & printing packages
- **UI**: Material Design 3

### Backend
- **Language**: PHP 7.4+
- **Database**: MySQL
- **API**: RESTful with JSON responses
- **Authentication**: API Key-based
- **CORS**: Configured for cross-origin requests

### Key Features
- **Cache-Busting**: Real-time data updates
- **Error Handling**: Graceful error messages
- **Responsive Design**: Works on all screen sizes
- **Offline Support**: Basic offline functionality
- **PDF Reports**: Professional report generation

## 📦 Production Builds

### Web App
```bash
flutter build web --release
# Deploy build/web/ to any web hosting
```

### Android APK
```bash
flutter build apk --release
# APK available at build/app/outputs/flutter-apk/app-release.apk
```

### iOS App
```bash
flutter build ios --release
# Requires Xcode and Apple Developer account
```

## 🌐 Deployment

### Web Deployment Options
1. **Netlify** (Recommended) - Drag & drop deployment
2. **Vercel** - Git-based deployment
3. **GitHub Pages** - Free hosting
4. **Traditional Web Hosting** - Upload to server

### Mobile Deployment
- **Android**: Upload APK to Google Play Store
- **iOS**: Upload to App Store Connect

## 🔐 Security Features

- API Key authentication
- CORS headers configuration
- Input validation and sanitization
- SQL injection prevention
- XSS protection

## 📊 Database Schema

### Sales Table
```sql
CREATE TABLE sales (
    id INT PRIMARY KEY AUTO_INCREMENT,
    txn_date DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_method ENUM('cash', 'online') NOT NULL,
    note TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Borrowings Table
```sql
CREATE TABLE borrowings (
    id INT PRIMARY KEY AUTO_INCREMENT,
    txn_date DATE NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    is_repayment BOOLEAN DEFAULT FALSE,
    note TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Solar Daily Table
```sql
CREATE TABLE solar_daily (
    id INT PRIMARY KEY AUTO_INCREMENT,
    reading_date DATE UNIQUE NOT NULL,
    import_kwh DECIMAL(10,3) DEFAULT 0,
    export_kwh DECIMAL(10,3) DEFAULT 0,
    generation_kwh DECIMAL(10,3) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 🐛 Troubleshooting

### Common Issues
1. **Network Connection**: Ensure device has internet access
2. **API Permissions**: Check Android manifest for internet permissions
3. **Database Connection**: Verify MySQL credentials and connection
4. **CORS Issues**: Check backend CORS configuration

### Debug Mode
```bash
flutter run --debug
# Check console for detailed error messages
```

## 📈 Performance Optimizations

- **Cache-Busting**: Prevents stale data display
- **Image Optimization**: Compressed assets
- **Code Splitting**: Efficient bundle sizes
- **Lazy Loading**: On-demand data loading
- **Memory Management**: Proper resource cleanup

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is proprietary software developed for Solar Burji business management.

## 📞 Support

For technical support or customization requests:
- **Email**: [Your Email]
- **Phone**: [Your Phone]
- **WhatsApp**: [Your WhatsApp]

## 🔄 Version History

- **v1.0.0** - Initial release with sales, borrowings, and solar monitoring
- **v1.0.1** - Added cache-busting and network permissions
- **v1.0.2** - Enhanced error handling and UI improvements

---

⭐ **Star this repository if you find it helpful!**

*Built with ❤️ for Solar Burji Business Management*
