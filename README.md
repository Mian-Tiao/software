# Memory Assistant

Memory Assistant is a Flutter-based mobile application designed to support daily memory care, personal scheduling, emotional check-ins, and caregiver assistance. The project focuses mainly on Android development and integrates Firebase, Gemini API, speech interaction, local notifications, background alarms, location tracking, and media-based memory records.

The app is intended for users who need gentle daily support and for caregivers who need a clearer way to follow tasks, safety status, and selected care information.

## Features

- User registration and login with Firebase Authentication
- Role-based flow for care receivers and caregivers
- Daily task management with calendar-style scheduling
- AI companion chat for reminders, emotional support, and task-related guidance
- Speech-to-text input for creating and interacting with tasks
- Text-to-speech responses for a more accessible companion experience
- Mood check-in records stored in Firestore
- Personal memory album with image/audio records
- Cloud media upload support through Cloudinary/Firebase-related services
- Local notifications for task reminders and AI companion prompts
- Android background alarm scheduling for morning and evening reminders
- Location sharing and caregiver map view with Google Maps
- Safe-zone related settings for caregiver monitoring scenarios

## Tech Stack

### Frontend

- Flutter
- Dart
- Material Design
- Android-first mobile development

### Backend and Cloud Services

- Firebase Core
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Google Maps Platform
- Cloudinary upload API
- Gemini API through HTTP requests

### Mobile Capabilities

- `speech_to_text` for voice input
- `flutter_tts` for speech output
- `flutter_local_notifications` for local notification delivery
- `android_alarm_manager_plus` for Android background scheduling
- `geolocator` and `geocoding` for location features
- `google_maps_flutter` for caregiver map display
- `permission_handler` for runtime permission handling
- `image_picker`, `file_picker`, `record`, and `just_audio` for memory media features
- `flutter_dotenv` for local environment variables

## Project Structure

```text
lib/
  main.dart                         App entry point and route registration
  firebase_options.dart             Firebase platform configuration

  pages/
    login_page.dart                 Login flow
    register_page.dart              Account registration
    main_menu_page.dart             Main user home screen
    user_task_page.dart             Task calendar and voice task input
    ai_companion_page.dart          AI companion chat UI
    mood_checkin_sheet.dart         Daily mood input
    profile_page.dart               User profile management
    monthly_overview_page.dart      Monthly task overview

  caregivers/
    role_selection_page.dart        Role selection after login
    caregiver_home_page.dart        Caregiver dashboard
    bind_user_page.dart             Bind caregiver to care receiver
    select_user_page.dart           Select care receiver
    map.dart                        Care receiver location map
    caregiver_profile_page.dart     Caregiver profile
    task_statistics_page.dart       Task statistics

  memoirs/
    memory_page.dart                Memory album
    add_memory_page.dart            Add memory record
    edit_memory_page.dart           Edit memory record
    memory_service.dart             Memory data operations
    cloudinary_upload.dart          Cloud media upload helper

  services/
    ai_companion_service.dart       Gemini, TTS, task reminder, memory replay logic
    notification_service.dart       Local notification setup and scheduling
    background_tasks.dart           Android morning/night background alarms
    location_uploader.dart          Location update upload to Firestore
    mood_service.dart               Mood check-in persistence
    safe_zone_setting_page.dart     Safe-zone setting page
    timezone_helper.dart            Local timezone helper

  widgets/
    home_overview_cards.dart        Home overview widgets
    safety_quick_card.dart          Safety summary widget
    today_summary_panel.dart        Daily summary widget
```

## Android Configuration

This project is mainly developed for Android. Important Android files include:

- `android/app/src/main/AndroidManifest.xml`
- `android/app/build.gradle.kts`
- `android/app/google-services.json`
- `android/settings.gradle.kts`

The Android manifest includes permissions for:

- Internet access
- Audio recording
- Notifications
- Exact alarms
- Wake lock
- Foreground service
- Fine/coarse/background location
- Full-screen notification intent

Google Maps API key injection is handled in `android/app/build.gradle.kts` through `secrets.properties` or the `GOOGLE_MAPS_API_KEY` environment variable.

Example `android/secrets.properties`:

```properties
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

## Environment Variables

The Flutter app loads `.env` at startup through `flutter_dotenv`.

Create a `.env` file in the project root:

```env
GEMINI_API_KEY=your_gemini_api_key
```

Do not commit real API keys or private service credentials.

## Getting Started

### Requirements

- Flutter SDK
- Dart SDK
- Android Studio or Android SDK command-line tools
- Android emulator or physical Android device
- Firebase project configured for Android
- Google Maps API key
- Gemini API key

On Windows, Flutter plugin projects require symlink support. Enable Developer Mode if `flutter pub get` shows a symlink error:

```powershell
start ms-settings:developers
```

### Install Dependencies

```powershell
cd E:\memory\software
flutter pub get
```

### Run on Android

```powershell
flutter devices
flutter run -d <device-id>
```

### Analyze the Project

```powershell
flutter analyze
```

## Firebase Data Usage

The app uses Firebase Authentication for account identity and Cloud Firestore for application data. Main data areas include:

- `users`
- `users/{uid}/tasks`
- `caregivers`
- `memories`
- `ai_companion`
- mood-related user records

Task records are stored under each user and include fields such as task title, start time, end time, type, completion state, and date.

## Development Notes

- The project currently includes multiple generated platform folders, but Android is the primary target.
- `lib/main.dart` initializes notifications, environment variables, Firebase, and app routing.
- `NotificationService` centralizes local notification setup and exact alarm behavior.
- `BackgroundTasks` schedules Android morning and evening AI reminder callbacks.
- `AICompanionService` connects task data, Gemini responses, TTS, and memory audio replay.
- `LocationUploader` updates Firestore with the user's location when location sharing is enabled.

## Project Purpose

Memory Assistant combines reminder management, emotional support, memory recording, and caregiver visibility into one mobile application. Instead of being only a calendar or only a chat app, it connects daily tasks, AI conversation, voice interaction, mood tracking, and caregiver safety features to support a more complete memory-care workflow.
