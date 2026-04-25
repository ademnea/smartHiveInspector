# Unit Test Report

Generated: 2026-04-25

These tests are stored under `test/unit`. They are written to avoid live API calls and external services where possible. They have not been run in this pass because the plan is to decide how to run each suite later.

## Test Inventory

| Test file | Test | Source unit covered | What it checks | Result |
| --- | --- | --- | --- | --- |
| `test/unit/api_service_test.dart` | `fetchFarms sends bearer token and parses farm list` | `lib/Services/api_service.dart` | Confirms `/farms` request URL, bearer token header, and farm JSON parsing through a fake HTTP client. | Not run |
| `test/unit/api_service_test.dart` | `fetchHives parses hive list for a farm endpoint` | `lib/Services/api_service.dart` | Confirms `/farms/{id}/hives` request URL and hive JSON parsing. | Not run |
| `test/unit/api_service_test.dart` | `fetchTemperatureData includes start and end date query parameters` | `lib/Services/api_service.dart` | Confirms date-range query construction for hive temperature data. | Not run |
| `test/unit/api_service_test.dart` | `submitInspectionRecord posts JSON and returns true on created response` | `lib/Services/api_service.dart` | Confirms inspection payload JSON is posted and `201` is treated as success. | Not run |
| `test/unit/api_service_test.dart` | `isApiReachable and getServerStatus handle success and error states` | `lib/Services/api_service.dart` | Confirms health/status utility endpoints parse successful fake responses. | Not run |
| `test/unit/auth_manager_test.dart` | `isAuthenticated returns false when no token is stored` | `lib/Services/auth_manager.dart` | Confirms missing auth state is treated as unauthenticated. | Not run |
| `test/unit/auth_manager_test.dart` | `ensureValidToken returns true for a stored unexpired token` | `lib/Services/auth_manager.dart` | Confirms stored non-expired tokens are accepted. | Not run |
| `test/unit/auth_manager_test.dart` | `authenticated GET adds bearer token and returns response` | `lib/Services/auth_manager.dart` | Confirms authenticated GET includes bearer and custom headers through a fake HTTP client. | Not run |
| `test/unit/auth_manager_test.dart` | `authenticated POST JSON-encodes map body` | `lib/Services/auth_manager.dart` | Confirms authenticated POST serializes map bodies to JSON. | Not run |
| `test/unit/auth_manager_test.dart` | `authenticated PUT passes string body unchanged` | `lib/Services/auth_manager.dart` | Confirms authenticated PUT preserves pre-encoded string bodies. | Not run |
| `test/unit/auth_manager_test.dart` | `authenticated DELETE sends request with auth header` | `lib/Services/auth_manager.dart` | Confirms authenticated DELETE sends the bearer token header. | Not run |
| `test/unit/auth_manager_test.dart` | `authenticatedRequest returns null for unsupported methods` | `lib/Services/auth_manager.dart` | Confirms unsupported HTTP methods fail safely. | Not run |
| `test/unit/auth_manager_test.dart` | `authenticatedRequest returns null when no valid token is available` | `lib/Services/auth_manager.dart` | Confirms network requests are skipped when auth is unavailable. | Not run |
| `test/unit/auth_manager_test.dart` | `logout clears token and cached auth state` | `lib/Services/auth_manager.dart` | Confirms logout clears stored token and user ID. | Not run |
| `test/unit/auth_service_test.dart` | `getToken reads from TokenStorage when memory token is empty` | `lib/Services/auth_services.dart` | Confirms the auth service can resolve token state from persistent storage. | Not run |
| `test/unit/auth_service_test.dart` | `isLoggedIn returns true when a token is stored` | `lib/Services/auth_services.dart` | Confirms stored token state is treated as logged in. | Not run |
| `test/unit/app_utils_test.dart` | `DateTimeUtils startOfDay returns midnight for the given date` | `lib/utils/app_utils.dart` | Confirms `startOfDay` strips time values from a `DateTime`. | Not run |
| `test/unit/app_utils_test.dart` | `DateTimeUtils formats readable and API dates` | `lib/utils/app_utils.dart` | Confirms readable, API, and date-time display formatting. | Not run |
| `test/unit/app_utils_test.dart` | `DateTimeUtils calculates whole calendar days between two dates` | `lib/utils/app_utils.dart` | Confirms date difference is based on calendar days. | Not run |
| `test/unit/app_utils_test.dart` | `StringUtils capitalizes words and preserves spacing` | `lib/utils/app_utils.dart` | Confirms title-style capitalization and empty-string handling. | Not run |
| `test/unit/app_utils_test.dart` | `StringUtils truncates and shortens long strings` | `lib/utils/app_utils.dart` | Confirms truncation and shortened ID display. | Not run |
| `test/unit/app_utils_test.dart` | `StringUtils removes special characters` | `lib/utils/app_utils.dart` | Confirms punctuation removal while keeping words and spaces. | Not run |
| `test/unit/app_utils_test.dart` | `MathUtils calculates average, min, max, power, and clamp` | `lib/utils/app_utils.dart` | Confirms core numeric helper outputs and empty-list average behavior. | Not run |
| `test/unit/app_utils_test.dart` | `MathUtils rounds to decimal places` | `lib/utils/app_utils.dart` | Confirms decimal rounding behavior. | Not run |
| `test/unit/app_utils_test.dart` | `ColorUtils lightens and darkens colors` | `lib/utils/app_utils.dart` | Confirms RGB adjustment calculations. | Not run |
| `test/unit/app_utils_test.dart` | `ColorUtils detects dark colors and picks contrasting text` | `lib/utils/app_utils.dart` | Confirms brightness detection and text color selection. | Not run |
| `test/unit/app_utils_test.dart` | `FormatUtils formats common display values` | `lib/utils/app_utils.dart` | Confirms date, percentage, weight, duration, and temperature display helpers. | Not run |
| `test/unit/overview_card_test.dart` | `buildOverviewCard renders title, value, and icon` | `lib/apiary_overview_cards/build_overview_card.dart` | Confirms the apiary overview card displays its label, value, and icon. | Not run |
| `test/unit/farm_card_test.dart` | `buildFarmCard renders apiary details and action buttons` | `lib/farm_card.dart` | Confirms the apiary/farm card displays farm name, location, indicators, and Manage/Edit/Delete actions. | Not run |
| `test/unit/farm_card_test.dart` | `buildFarmCard delete action can be cancelled without deleting` | `lib/farm_card.dart` | Confirms the delete confirmation dialog opens and cancel does not call the deletion callback. | Not run |
| `test/unit/hive_card_widget_test.dart` | `HiveCard renders hive state and inspection action` | `lib/components/hive_card.dart` | Confirms the hive card displays hive name, connection, colonization, and inspection action. | Not run |
| `test/unit/hive_status_card_test.dart` | `HiveStatusCard renders hive and weather readings` | `lib/notifications/hive_status_card.dart` | Confirms the hive status card displays live hive readings and weather fields. | Not run |
| `test/unit/notification_card_widget_test.dart` | `NotificationCard renders severity and expected action buttons` | `lib/notifications/notification_card.dart` | Confirms notification cards show title, message, severity, and type-specific actions. | Not run |
| `test/unit/custom_progress_bar_test.dart` | `CustomProgressBar maps temperature values to progress and colors` | `lib/components/custom_progress_bar.dart` | Confirms temperature thresholds map to progress values and colors. | Not run |
| `test/unit/pop_up_test.dart` | `popup message helpers return expected threshold messages` | `lib/components/pop_up.dart` | Confirms temperature and honey modal message threshold helpers. | Not run |
| `test/unit/cache_service_test.dart` | `saveFarms and loadFarms persist farm cache data` | `lib/Services/cache_service.dart` | Confirms offline farm cache persistence and timestamp storage. | Not run |
| `test/unit/cache_service_test.dart` | `saveHives and loadHives persist per-farm hive cache data` | `lib/Services/cache_service.dart` | Confirms offline hive cache persistence per farm. | Not run |
| `test/unit/cache_service_test.dart` | `saveData loadData hasCachedData and clearCache manage generic cache` | `lib/Services/cache_service.dart` | Confirms generic offline cache save/load/existence/clear behavior. | Not run |
| `test/unit/cache_service_test.dart` | `load methods return null for malformed cached JSON` | `lib/Services/cache_service.dart` | Confirms malformed cached values fail safely. | Not run |
| `test/unit/component_widgets_test.dart` | `CustomTextField renders hint, prefix icon, suffix icon, and accepts input` | `lib/components/custom_text_field.dart` | Confirms the custom text field renders expected decoration and writes to its controller. | Not run |
| `test/unit/component_widgets_test.dart` | `HiveTips renders title and content` | `lib/components/hive_tips.dart` | Confirms hive tip cards render their title and body text. | Not run |
| `test/unit/component_widgets_test.dart` | `NotificationComponent renders date, title, and content` | `lib/components/notificationbar.dart` | Confirms notification banner content renders. | Not run |
| `test/unit/component_widgets_test.dart` | `basic honey and temperature sheets render titles and values` | `lib/components/honey_sheet.dart`, `lib/components/temperature_sheet.dart` | Confirms simple sheet widgets render their titles and numeric values. | Not run |
| `test/unit/component_widgets_test.dart` | `TabItem hides zero count and caps high counts at 9+` | `lib/tab_item.dart` | Confirms tab badge behavior for zero and high counts. | Not run |
| `test/unit/component_widgets_test.dart` | `IndividualBar stores chart point values` | `lib/components/individual_bar.dart` | Confirms chart bar value assignment. | Not run |
| `test/unit/farm_model_test.dart` | `Farm.fromJson supports ownerId casing and numeric conversions` | `lib/farm_model.dart` | Confirms API JSON is parsed with both `OwnerId` and numeric/string coordinate values. | Not run |
| `test/unit/farm_model_test.dart` | `Farm.toJson emits API field names` | `lib/farm_model.dart` | Confirms serialized farm data uses expected API keys, including `longitude`. | Not run |
| `test/unit/hive_model_test.dart` | `Hive.fromJson parses nested hive state and convenience getters` | `lib/hive_model.dart` | Confirms hive state parsing for weight, temperature, humidity, CO2, connection, and colonization. | Not run |
| `test/unit/hive_model_test.dart` | `HiveData.fromApiHive maps missing state to safe defaults` | `lib/hive_model.dart` | Confirms UI hive data falls back safely when no sensor state exists. | Not run |
| `test/unit/home_data_test.dart` | `HomeData.fromJson maps dashboard count, productive, and season data` | `lib/home.dart` | Confirms dashboard summary JSON is mapped into `HomeData`. | Not run |
| `test/unit/bee_counter_model_test.dart` | `ServerVideo.fromJson extracts timestamp from filename` | `lib/bee_counter/bee_counter_model.dart` | Confirms server video filenames are converted into timestamps and interval matches. | Not run |
| `test/unit/bee_counter_model_test.dart` | `ServerVideo.fromJson falls back to lastModified timestamp` | `lib/bee_counter/bee_counter_model.dart` | Confirms Unix `last_modified` fallback timestamp parsing. | Not run |
| `test/unit/bee_counter_model_test.dart` | `BeeCount calculates activity and serializes JSON` | `lib/bee_counter/bee_counter_model.dart` | Confirms net change, total activity, JSON output, and JSON input. | Not run |
| `test/unit/bee_counter_model_test.dart` | `BeeCount.copyWith replaces selected fields only` | `lib/bee_counter/bee_counter_model.dart` | Confirms copy behavior preserves unchanged fields. | Not run |
| `test/unit/bee_counter_model_test.dart` | `BeeAnalysisResult maps to and from JSON` | `lib/bee_counter/bee_counter_model.dart` | Confirms bee analysis result JSON mapping and summary string. | Not run |
| `test/unit/bee_weatherdata_test.dart` | `bee counter WeatherData parses JSON and applies optional defaults` | `lib/bee_counter/weatherdata.dart` | Confirms bee-counter weather JSON parsing and default rainfall/solar radiation values. | Not run |
| `test/unit/bee_weatherdata_test.dart` | `bee counter WeatherData serializes all weather fields` | `lib/bee_counter/weatherdata.dart` | Confirms bee-counter weather JSON output. | Not run |
| `test/unit/bee_video_analysis_result_test.dart` | `BeeAnalysisResult serializes all video analysis fields` | `lib/bee_counter/bee_video_analysis_result.dart` | Confirms video analysis result serialization. | Not run |
| `test/unit/bee_video_analysis_result_test.dart` | `BeeAnalysisResult.fromJson restores all values` | `lib/bee_counter/bee_video_analysis_result.dart` | Confirms video analysis result deserialization and summary string. | Not run |
| `test/unit/foraging_efficiency_metric_test.dart` | `ForagingEfficiencyMetric.fromJson maps stored metric values` | `lib/bee_counter/foraging_efficiency_metric.dart` | Confirms stored foraging efficiency metrics are parsed. | Not run |
| `test/unit/foraging_efficiency_metric_test.dart` | `ForagingEfficiencyMetric.toJson emits persisted fields` | `lib/bee_counter/foraging_efficiency_metric.dart` | Confirms metric JSON output for persisted fields. | Not run |
| `test/unit/foraging_efficiency_metric_test.dart` | `ForagingEfficiencyMetric.copyWith replaces selected values` | `lib/bee_counter/foraging_efficiency_metric.dart` | Confirms copy behavior and preservation of peak time/return rate. | Not run |
| `test/unit/foraging_efficiency_metric_test.dart` | `ForagingEfficiencyCalculator scores optimal periods higher than poor conditions` | `lib/bee_counter/foraging_efficiency_metric.dart` | Confirms efficiency scoring stays in range and rewards better conditions. | Not run |
| `test/unit/notification_model_test.dart` | `HiveNotification.copyWith keeps existing values and overrides selected ones` | `lib/notifications/notification_model.dart` | Confirms notification copy behavior. | Not run |
| `test/unit/notification_model_test.dart` | `HiveNotification maps type to icon and severity to color` | `lib/notifications/notification_model.dart` | Confirms notification type icons and severity colors. | Not run |
| `test/unit/notification_model_test.dart` | `HiveNotification.timeAgo returns readable recent durations` | `lib/notifications/notification_model.dart` | Confirms recent notification time labels. | Not run |
| `test/unit/profile_screen_test.dart` | `shows loaded profile details from the injected profile response` | `lib/profile.dart` | Confirms `ProfileScreen` renders name, email, user ID, and role from a successful profile response. | Not run |
| `test/unit/profile_screen_test.dart` | `change password row explains that the feature is not wired yet` | `lib/profile.dart` | Confirms tapping `Change Password` shows the current placeholder SnackBar. | Not run |
| `test/unit/queue_services_test.dart` | `ApiaryQueueItem serializes add and edit actions` | `lib/Services/apiary_queue_service.dart` | Confirms queued apiary action JSON mapping. | Not run |
| `test/unit/queue_services_test.dart` | `ApiaryQueueService adds, reads, removes, and clears queued items` | `lib/Services/apiary_queue_service.dart` | Confirms apiary queue persistence behavior with mocked `SharedPreferences`. | Not run |
| `test/unit/queue_services_test.dart` | `QueuedOperation serializes and increments retry count` | `lib/Services/offline_queue_service.dart` | Confirms offline operation JSON mapping and retry copy behavior. | Not run |
| `test/unit/queue_services_test.dart` | `OfflineQueueService queues typed operations and reports queue state` | `lib/Services/offline_queue_service.dart` | Confirms offline helper methods queue farm/hive/record operations and report counts/filtering. | Not run |
| `test/unit/queue_services_test.dart` | `OfflineQueueService removes one operation and clears the queue` | `lib/Services/offline_queue_service.dart` | Confirms queued operations can be removed individually and fully cleared. | Not run |
| `test/unit/queue_services_test.dart` | `OfflineQueueService stores and reads sync status` | `lib/Services/offline_queue_service.dart` | Confirms offline sync status persistence. | Not run |
| `test/unit/queue_services_test.dart` | `OfflineQueueService skips malformed queued operation JSON` | `lib/Services/offline_queue_service.dart` | Confirms malformed queue entries are ignored instead of crashing queue reads. | Not run |
| `test/unit/queue_services_test.dart` | `syncQueuedOperations does not run when already syncing` | `lib/Services/offline_queue_service.dart` | Confirms sync is skipped when a sync is already marked in progress. | Not run |
| `test/unit/queue_services_test.dart` | `SyncResult stores success, error, and response data` | `lib/Services/offline_queue_service.dart` | Confirms sync result value storage. | Not run |
| `test/unit/token_storage_test.dart` | `saveLoginData stores token, user fields, and profile payload` | `lib/Services/token_storage.dart` | Confirms login data and cached profile data are saved through `TokenStorage`. | Not run |
| `test/unit/token_storage_test.dart` | `clearLoginData removes saved authentication and profile data` | `lib/Services/token_storage.dart` | Confirms logout cleanup removes saved auth and profile values. | Not run |
| `test/unit/video_file_test.dart` | `VideoFile stores local video metadata` | `lib/models/video_file.dart` | Confirms local video metadata is assigned correctly. | Not run |
| `test/unit/weather_service_test.dart` | `getCurrentWeather returns decoded response on success` | `lib/Services/weather_service.dart` | Confirms current weather API response decoding and request URL construction through a fake HTTP client. | Not run |
| `test/unit/weather_service_test.dart` | `getCurrentWeather returns error map on non-200 response` | `lib/Services/weather_service.dart` | Confirms non-success weather API responses produce an error map. | Not run |
| `test/unit/weather_service_test.dart` | `getWeatherForDate returns historical data for past dates` | `lib/Services/weather_service.dart` | Confirms past-date weather requests use the historical endpoint. | Not run |
| `test/unit/weather_service_test.dart` | `getWeatherSummary extracts normalized weather fields` | `lib/Services/weather_service.dart` | Confirms weather summaries normalize temperature, humidity, wind, precipitation, UV, and location fields. | Not run |
| `test/unit/weather_service_test.dart` | `getWeatherData returns the current dummy weather object` | `lib/Services/weather_service.dart` | Confirms the current latitude/longitude weather method returns its placeholder object. | Not run |
| `test/unit/weather_model_test.dart` | `WeatherData.fromJson converts numeric fields to doubles` | `lib/notifications/weather_model.dart` | Confirms weather JSON parsing, numeric conversion, timestamp parsing, and rain detection. | Not run |
| `test/unit/weather_model_test.dart` | `WeatherData.toJson emits stored values` | `lib/notifications/weather_model.dart` | Confirms weather JSON serialization and non-rain condition detection. | Not run |

## Suggested Run Commands

Run the whole unit suite:

```bash
flutter test test/unit
```

Run one test file:

```bash
flutter test test/unit/app_utils_test.dart
flutter test test/unit/api_service_test.dart
flutter test test/unit/auth_manager_test.dart
flutter test test/unit/auth_service_test.dart
flutter test test/unit/bee_weatherdata_test.dart
flutter test test/unit/cache_service_test.dart
flutter test test/unit/component_widgets_test.dart
flutter test test/unit/custom_progress_bar_test.dart
flutter test test/unit/farm_model_test.dart
flutter test test/unit/farm_card_test.dart
flutter test test/unit/hive_model_test.dart
flutter test test/unit/hive_card_widget_test.dart
flutter test test/unit/hive_status_card_test.dart
flutter test test/unit/home_data_test.dart
flutter test test/unit/bee_counter_model_test.dart
flutter test test/unit/bee_video_analysis_result_test.dart
flutter test test/unit/foraging_efficiency_metric_test.dart
flutter test test/unit/notification_model_test.dart
flutter test test/unit/notification_card_widget_test.dart
flutter test test/unit/overview_card_test.dart
flutter test test/unit/pop_up_test.dart
flutter test test/unit/profile_screen_test.dart
flutter test test/unit/queue_services_test.dart
flutter test test/unit/token_storage_test.dart
flutter test test/unit/video_file_test.dart
flutter test test/unit/weather_service_test.dart
flutter test test/unit/weather_model_test.dart
```

## Previous Runner Note

Earlier attempts to run `flutter test test/unit` on this machine timed out before test output was produced. Because of that environment behavior, this document now marks the expanded tests as `Not run` until we choose and verify a runner strategy.
