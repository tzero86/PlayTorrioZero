/// Simkl API constants dynamically loaded from environment.
library;

import '../config/env_service.dart';

String get kSimklClientId => EnvService.simklClientId;
String get kSimklClientSecret => EnvService.simklClientSecret;

const String kSimklApiBaseUrl = 'https://api.simkl.com';

/// App name Simkl sees, from `SIMKL_APP_NAME` at build time, defaulting to 'ZPlay'.
String get kSimklAppName => EnvService.simklAppName;

const String kSimklAppVersion = '1.0';

/// CDN host for the pre-built trending data files (public, no auth).
const String kSimklTrendingUrl =
    'https://data.simkl.in/discover/trending/today_100.json';

/// CDN calendar file (public, no auth): upcoming episode air dates for all TV shows.
const String kSimklCalendarTvUrl = 'https://data.simkl.in/calendar/tv.json';

const String kSimklPinUrl = '$kSimklApiBaseUrl/oauth/pin';
String simklPinPollUrl(String userCode) => '$kSimklPinUrl/$userCode';
