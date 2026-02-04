// ignore: constant_identifier_names
const String API_BASE_URL = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

const String API_VERSION = '/api/v1';

// Supported Banks
const List<String> SUPPORTED_BANKS = [
  'CTBC',
  'Cathay United Bank',
  'Taishin Bank',
];

// Storage Keys
const String KEY_ACCESS_TOKEN = 'access_token';
const String KEY_REFRESH_TOKEN = 'refresh_token';
const String KEY_USER_ID = 'user_id';
const String KEY_USER_PHONE = 'user_phone';
const String KEY_USER_EMAIL = 'user_email';
const String KEY_BIOMETRIC_ENABLED = 'biometric_enabled';
const String KEY_FIRST_LAUNCH = 'first_launch';

// Animation Durations
const int ANIMATION_DURATION_SHORT = 200;
const int ANIMATION_DURATION_MEDIUM = 300;
const int ANIMATION_DURATION_LONG = 500;

// Pagination
const int DEFAULT_PAGE_SIZE = 20;

// File Upload
const int MAX_FILE_SIZE_MB = 10;
const List<String> ALLOWED_FILE_TYPES = [
  'pdf',
  'jpg',
  'jpeg',
  'png',
  'heic',
];
