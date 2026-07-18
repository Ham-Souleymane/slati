# Firebase Setup Guide – Slatk

This guide outlines the step-by-step instructions to configure Firebase and Google Sign-In for the **Slatk** app.

---

## Phase 1: Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** and name it `slatkapp` (or choose your preferred name).
3. (Optional) Enable Google Analytics for the project.
4. Click **Create project** and wait for provisioning.

---

## Phase 2: Platform Configuration (Android & iOS)

### 1. Android Configuration

#### Step A: Register the App
1. Inside your Firebase project dashboard, click the **Android icon** to add an Android app.
2. Enter the Package Name: `com.slatk.slatkapp`.
3. (Optional) Enter the App Nickname: `Slatk Android`.
4. **Important for Google Sign-in**: Enter your SHA-1 fingerprint.
   - To generate SHA fingerprints on your local machine, run:
     ```powershell
     # Run in terminal (Windows)
     keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore
     # Default keystore password is: android
     ```
   - Copy the SHA-1 and SHA-256 fingerprints and paste them into the registration field.
5. Click **Register App**.

#### Step B: Add Configuration Files
1. Download `google-services.json`.
2. Move it into your Flutter project at:
   `android/app/google-services.json` (replacing the placeholder file).

#### Step C: Add Firebase Build Plugins
1. Open `android/settings.gradle` and ensure you have the google-services dependency:
   ```groovy
   plugins {
       // ...
       id "com.google.gms.google-services" version "4.4.2" apply false
   }
   ```
2. Open `android/app/build.gradle` and apply the plugin:
   ```groovy
   plugins {
       id "com.android.application"
       id "kotlin-android"
       id "dev.flutter.flutter-gradle-plugin"
       id "com.google.gms.google-services" // Add this line
   }
   ```
3. Set your `minSdkVersion` to `21` or higher in `android/app/build.gradle` (default is 21 in modern Flutter templates).

---

### 2. iOS Configuration

#### Step A: Register the App
1. Inside your Firebase project dashboard, click **Add app** and select the **iOS icon**.
2. Enter the Bundle ID: `com.slatk.slatkapp` (ensure this matches the Bundle Identifier in Xcode).
3. Enter App Nickname: `Slatk iOS`.
4. Click **Register App**.

#### Step B: Add Configuration Files
1. Download `GoogleService-Info.plist`.
2. Move/drag this file into Xcode at `Runner/Runner` (or place it at `ios/Runner/GoogleService-Info.plist` in your project folder and add it to the Xcode targets group).

#### Step C: Configure iOS URL Schemes (Required for Google Sign-in)
1. Open the downloaded `GoogleService-Info.plist` and look for the key `REVERSED_CLIENT_ID` (looks like `com.googleusercontent.apps.xxxxxxxxxx-xxxxxxxxxx`).
2. Open `ios/Runner/Info.plist` in your editor.
3. Locate the `CFBundleURLTypes` section, and replace `YOUR_REVERSED_CLIENT_ID` with the actual value from your plist:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleTypeRole</key>
           <string>Editor</string>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>com.googleusercontent.apps.xxxxxxxxxx-xxxxxxxxxx</string>
           </array>
       </dict>
   </array>
   ```

---

## Phase 3: Enable Authentication Providers

1. In the Firebase console sidebar, navigate to **Build** > **Authentication**.
2. Click **Get Started**.
3. Under the **Sign-in method** tab, enable:
   - **Email/Password**: Toggle status to Enabled.
   - **Google**: Toggle status to Enabled.
     - Choose a project support email.
     - Click **Save**.

---

## Phase 4: Configure with FlutterFire CLI (Alternative/Preferred Method)

Instead of manually editing files, you can use the FlutterFire CLI to automatically configure the project for all platforms:

1. Install Firebase CLI tools globally on your machine:
   [Firebase CLI Reference](https://firebase.google.com/docs/cli)
2. Log in to your Firebase account:
   ```bash
   firebase login
   ```
3. Install the FlutterFire CLI globally:
   ```bash
   dart pub global activate flutterfire_cli
   ```
4. Run the configure command from the root of your project:
   ```bash
   flutterfire configure
   ```
5. Select your Firebase project and select `android` and `ios` platforms.
6. The CLI will automatically create/update `lib/firebase_options.dart` and download the platform configuration files (`google-services.json` and `GoogleService-Info.plist`) with the correct configurations.
