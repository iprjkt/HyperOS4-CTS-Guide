# HyperOS Circle to Search (CTS) Integration Guide (No LSPosed)
*Panduan Integrasi Circle to Search (CTS) ke dalam ROM HyperOS (Tanpa LSPosed)*

[English](#english) | [Bahasa Indonesia](#bahasa-indonesia)

---

<a name="english"></a>
## English

This guide details the native implementation and ROM integration of Google's **Circle to Search (Contextual Search)** feature into **Xiaomi HyperOS (Android 14+)** without requiring LSPosed or root runtime hooking modules.

---

### Table of Contents
1. [Architecture & Mechanism](#1-architecture--mechanism)
2. [Step 1: Enable Contextual Search in framework-res (Overlay & Permissions)](#step-1-enable-contextual-search-in-framework-res-overlay--permissions)
3. [Step 2: Bypass Permission in services.jar (Fix SecurityException)](#step-2-bypass-permission-in-servicesjar-fix-securityexception)
4. [Step 3: Device Spoofing for Google App in framework.jar](#step-3-device-spoofing-for-google-app-in-frameworkjar)
5. [Step 4: Redirect Navigation Bar Gesture (XiaoAi Replacement CTS Stub)](#step-4-redirect-navigation-bar-gesture-xiaoai-replacement-cts-stub)
6. [Step 5: Default Settings Database Configuration](#step-5-default-settings-database-configuration)
7. [Testing & Verification via ADB](#testing--verification-via-adb)

---

### 1. Architecture & Mechanism

On Android 14/15, Circle to Search relies on the AOSP contextual search subsystem: `ContextualSearchManagerService`.

```
[ Long-press Nav Bar ] ──> [ VoiceAssist Stub / MiuiHome ]
                                       │ (IPC Binder)
                                       ▼
                        [ ContextualSearchManagerService ]
                        - Default Provider: com.google.android.googlequicksearchbox
                        - Permission: Bypassed in services.jar
                                       │
                                       ▼
                        [ Google App (QuickSearchBox) ]
                        - Spoofed Device: Pixel 9 Pro (caiman)
                        - CTS Overlay Launched
```

#### Four Core Requirements:
1. **System Service:** `ContextualSearchManagerService` must be initialized at boot time.
2. **IPC Permission:** The caller must be allowed to invoke `startContextualSearch()` without `SecurityException`.
3. **Google App Spoofing:** Google App (AGSA) must identify the device as a Google Pixel family (e.g. Pixel 9 Pro `caiman`) to enable the CTS UI feature flags.
4. **Gesture Hook / Redirect:** The long-press event on the navigation bar (white bar) must trigger `IContextualSearchManager.startContextualSearch(1)`.

---

### Step 1: Enable Contextual Search in `framework-res` (Overlay & Permissions)

By default in Xiaomi HyperOS, `config_defaultContextualSearchPackageName` is empty (`""`). When empty, `SystemServer` skips initializing `ContextualSearchManagerService`.

#### 1.1 Runtime Resource Overlay (RRO)
Place an overlay APK in `/product/overlay/` or `/system_ext/overlay/`:

`res/values/config.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Register Google App as the Contextual Search provider -->
    <string name="config_defaultContextualSearchPackageName" translatable="false">com.google.android.googlequicksearchbox</string>
</resources>
```

`AndroidManifest.xml`:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.android.internal.overlay.cts"
    android:versionCode="1"
    android:versionName="1.0">
    <application android:hasCode="false" />
    <overlay
        android:targetPackage="android"
        android:priority="1000"
        android:isStatic="true" />
</manifest>
```

#### 1.2 System Feature Permission XML
HyperOS Launcher (`MiuiHome` via `libapp_launcher.so`) and Settings check for two declared system features:
1. `android.software.contextualsearch`
2. `com.google.android.feature.CONTEXTUAL_SEARCH`

Create `/product/etc/permissions/com.google.android.feature.CONTEXTUAL_SEARCH.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <feature name="android.software.contextualsearch" />
    <feature name="com.google.android.feature.CONTEXTUAL_SEARCH" />
</permissions>
```

---

### Step 2: Bypass Permission in `services.jar` (Fix SecurityException)

When non-system UIDs call `startContextualSearch()`, `ContextualSearchManagerService.enforcePermission()` throws:
`java.lang.SecurityException: Permission Denial: Cannot call startContextualSearch from pid=..., uid=...`

#### Smali Patching:
1. Decompile `services.jar`:
   ```bash
   baksmali d services.jar -o services_out
   ```
2. Open `services_out/com/android/server/contextualsearch/ContextualSearchManagerService.smali`.
3. Locate `enforcePermission(Ljava/lang/String;)V` and add `return-void` at the very beginning of the method:
   ```smali
   .method private synchronized enforcePermission(Ljava/lang/String;)V
       .registers 4

       return-void

       # Remaining original instructions...
   .end method
   ```
4. Rebuild `classes.dex` and update `services.jar`:
   ```bash
   smali a services_out -o classes2.dex
   # Note: dex files inside jar must be uncompressed (STORED / zip -0)
   ```

---

### Step 3: Device Spoofing for Google App in `framework.jar`

Google App checks `Build.BRAND`, `Build.MANUFACTURER`, `Build.MODEL`, and `Build.DEVICE`. If it is not a recognized Pixel or Samsung device, CTS features are hidden.

#### Option A: AOSP Source Code
In `frameworks/base/core/java/android/app/Instrumentation.java` or `ActivityThread.java`:
```java
public static void applyDeviceSpoofing(String packageName) {
    if ("com.google.android.googlequicksearchbox".equals(packageName)) {
        setBuildField("MANUFACTURER", "Google");
        setBuildField("BRAND", "google");
        setBuildField("MODEL", "Pixel 9 Pro");
        setBuildField("DEVICE", "caiman");
        setBuildField("PRODUCT", "caiman");
    }
}

private static void setBuildField(String key, String value) {
    try {
        Field field = Build.class.getDeclaredField(key);
        field.setAccessible(true);
        field.set(null, value);
    } catch (Exception ignored) {}
}
```

#### Option B: Smali Patching `framework.jar`
In `android/app/Application.smali` inside method `attach(Landroid/content/Context;)V`:
```smali
    invoke-virtual {p1}, Landroid/content/Context;->getPackageName()Ljava/lang/String;
    move-result-object v0
    const-string v1, "com.google.android.googlequicksearchbox"
    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v0
    if-eqz v0, :cond_skip_spoof

    const-string v0, "Google"
    sput-object v0, Landroid/os/Build;->MANUFACTURER:Ljava/lang/String;

    const-string v0, "google"
    sput-object v0, Landroid/os/Build;->BRAND:Ljava/lang/String;

    const-string v0, "Pixel 9 Pro"
    sput-object v0, Landroid/os/Build;->MODEL:Ljava/lang/String;

    const-string v0, "caiman"
    sput-object v0, Landroid/os/Build;->DEVICE:Ljava/lang/String;

    const-string v0, "caiman"
    sput-object v0, Landroid/os/Build;->PRODUCT:Ljava/lang/String;

    :cond_skip_spoof
```

---

### Step 4: Redirect Navigation Bar Gesture (XiaoAi Replacement CTS Stub)

In HyperOS, holding the gesture bar sends `android.intent.action.ASSIST` to XiaoAi (`com.miui.voiceassist/com.xiaomi.voiceassistant.VoiceService`).

Instead of keeping the bloated ~250MB XiaoAi APK:
1. Replace `/product/priv-app/VoiceAssistAndroidT/VoiceAssistAndroidT.apk` with a lightweight CTS Stub APK (**~1.9 MB** including original signature).
2. **Preserve Xiaomi Platform Signature (`[6c02dd51]`):**
   - **CRITICAL:** Do NOT sign with `testkey.keystore`. SELinux (`mac_permissions.xml`) will reject the privileged permissions if signature does not match.
   - Extract original `META-INF/` and APK Signing Block 42 from the stock XiaoAi APK and inject it into the stub APK using `scripts/inject_xiaomi_sig.py`.
3. **HyperOS Launcher Compatibility (`libapp_launcher.so`):**
   - Must include `<application>` metadata in `AndroidManifest.xml`:
     - `xiaoai.supportGestureLineWakeUp` = `true`
     - `ShortcutKeyWakeUpVersion` = `4`
     - `xiaoai.ShortcutKeyWakeUpVersion` = `2`
     - `is_super_ai` = `true`
   - Implement dummy `GlobalContentProvider` (`com.miui.voiceassist.contentprovider.GlobalContentProvider`) that handles method `getRecordAreaHeight` (returning integer `record_area_height_px`).
   - Implement dummy `GestureLineWakeUpSettingsActivity` & `GestureLineWakeUpSettingsActivityV2`.
4. **Android 14 Foreground Service Handling:**
   - Because `MiuiHome` starts the service via `startForegroundServiceAsUser`, `VoiceService.onStartCommand()` **must** immediately call `startForeground()` before triggering CTS, then call `stopForeground(1)` and `stopSelf()`. This prevents `ForegroundServiceDidNotStartInTimeException`.
5. **Direct IPC Binder Trigger:**
   In `VoiceService.triggerCTS()`:
   ```smali
   const-string v0, "contextual_search"
   invoke-static {v0}, Landroid/os/ServiceManager;->getService(Ljava/lang/String;)Landroid/os/IBinder;
   move-result-object v0
   if-nez v0, :cond_cs_found
   return-void

   :cond_cs_found
   invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
   move-result-object v1
   const-string v4, "android.app.contextualsearch.IContextualSearchManager"
   invoke-virtual {v1, v4}, Landroid/os/Parcel;->writeInterfaceToken(Ljava/lang/String;)V
   const/4 v2, 0x1
   invoke-virtual {v1, v2}, Landroid/os/Parcel;->writeInt(I)V   # entrypoint = 1
   const/4 v5, 0x0
   invoke-virtual {v1, v5}, Landroid/os/Parcel;->writeInt(I)V   # config = null (0)
   const/4 v4, 0x3
   invoke-interface {v0, v4, v1, v3, v2}, Landroid/os/IBinder;->transact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
   invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V
   ```

> [!TIP]
> **Prebuilt Modules & Binaries:**
> - [prebuilt/VoiceAssistCTS.apk](prebuilt/VoiceAssistCTS.apk) (~1.9 MB): Pre-compiled stub APK with original Xiaomi platform signature injected.
> - [prebuilt/VoiceAssistCTS-Magisk.zip](prebuilt/VoiceAssistCTS-Magisk.zip) (~801 KB): Flashable Magisk / KernelSU module to replace XiaoAi systemless-ly.
> - [prebuilt/CTSConfigOverlay.apk](prebuilt/CTSConfigOverlay.apk) (~3.5 KB): RRO APK for `framework-res` contextual search package config.
> - [prebuilt/CTSConfigOverlay-Magisk.zip](prebuilt/CTSConfigOverlay-Magisk.zip) (~4.0 KB): Magisk / KernelSU module for the RRO overlay + permissions XML.

---

### Step 5: Default Settings Database Configuration

Ensure defaults are set in `frameworks/base/packages/SettingsProvider/res/values/defaults.xml`:

```xml
<!-- Route nav bar long-press to VoiceAssistant trigger -->
<string name="def_nav_long_press" translatable="false">VoiceAssistant</string>

<!-- Set Google Assistant as default VoiceInteractionService -->
<string name="def_assistant" translatable="false">com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService</string>
<string name="def_voice_interaction_service" translatable="false">com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService</string>
<string name="def_voice_recognition_service" translatable="false">com.google.android.googlequicksearchbox/com.google.android.voicesearch.serviceapi.GoogleRecognitionService</string>

<!-- Grant screen context & screenshot permission for search analysis -->
<bool name="def_assist_structure_enabled">true</bool>
<bool name="def_assist_screenshot_enabled">true</bool>
```

Via ADB (for live systems):
```bash
adb shell settings put secure NavLongPress VoiceAssistant
adb shell settings put secure assistant com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService
adb shell settings put secure voice_interaction_service com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService
```

---

### Testing & Verification via ADB

1. **Verify `contextual_search` service status:**
   ```bash
   adb shell service list | grep contextual_search
   ```
   *Expected output:*
   ```text
   contextual_search: [android.app.contextualsearch.IContextualSearchManager]
   ```

2. **Trigger CTS directly via IPC Binder:**
   ```bash
   adb shell "service call contextual_search 1 i32 1"
   # Or via cmd:
   adb shell cmd contextual_search start 1
   ```

3. **Verify Long Press Navigation Gesture:**
   - Long press the white navigation bar handle at the bottom of the screen.
   - Screen will trigger the Google Circle to Search shimmer animation and overlay.

---

<br/>

---

<a name="bahasa-indonesia"></a>
## Bahasa Indonesia

Dokumen ini merupakan panduan implementasi langsung fitur **Circle to Search (Contextual Search)** ke dalam sistem / Custom ROM HyperOS (Android 14+), tanpa membutuhkan modul LSPosed maupun Xposed runtime hook.

---

### Daftar Isi
1. [Arsitektur & Prinsip Kerja](#1-arsitektur--prinsip-kerja-1)
2. [Langkah 1: Mengaktifkan Service di framework-res (Overlay & Permission)](#langkah-1-mengaktifkan-service-di-framework-res-overlay--permission)
3. [Langkah 2: Mem-bypass Permission di services.jar](#langkah-2-mem-bypass-permission-di-servicesjar-1)
4. [Langkah 3: Device Spoofing untuk Google App di framework.jar](#langkah-3-device-spoofing-untuk-google-app-di-frameworkjar-1)
5. [Langkah 4: Mengalihkan Trigger Gesture Navigasi (White Bar)](#langkah-4-mengalihkan-trigger-gesture-navigasi-white-bar-1)
6. [Langkah 5: Konfigurasi Default Settings Database](#langkah-5-konfigurasi-default-settings-database-1)
7. [Pengujian & Verifikasi via ADB](#pengujian--verifikasi-via-adb-1)

---

### 1. Arsitektur & Prinsip Kerja

Fitur Circle to Search di Android 14/15 mengandalkan sub-sistem bawaan bernama **Contextual Search** (`ContextualSearchManagerService`).

```
[ Long-press Bar Bawah ] ──> [ VoiceAssist / MiuiHome ]
                                       │ (IPC Binder)
                                       ▼
                        [ ContextualSearchManagerService ]
                        - Default Provider: com.google.android.googlequicksearchbox
                        - Permission: Bypassed / Whitelisted
                                       │
                                       ▼
                        [ Google App (QuickSearchBox) ]
                        - Spoofed Build: Pixel 9 Pro (caiman)
                        - Overlay CTS diluncurkan
```

Empat pilar utama yang harus dipenuhi:
1. **System Service:** `ContextualSearchManagerService` harus aktif saat booting.
2. **Permission IPC:** Izin `MANAGE_CONTEXTUAL_SEARCH` harus dibuka agar gesture launcher dapat memanggilnya tanpa `SecurityException`.
3. **Google App Spoofing:** Google App harus mendeteksi device sebagai keluarga Google Pixel agar fitur CTS tidak disembunyikan.
4. **Gesture Hook / Redirect:** Event tahan garis navigasi (*white-bar*) diarahkan ke `IContextualSearchManager.startContextualSearch(1)`.

---

### Langkah 1: Mengaktifkan Service di `framework-res` (Overlay & Permission)

Secara default di ROM HyperOS, `config_defaultContextualSearchPackageName` bernilai kosong (`""`). Jika kosong, `SystemServer` melewati inisialisasi `ContextualSearchManagerService`.

#### 1.1 Menggunakan Runtime Resource Overlay (RRO)
Buat paket overlay di `/product/overlay/` atau `/system_ext/overlay/`:

`res/values/config.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Mendaftarkan Google App sebagai penyedia Contextual Search -->
    <string name="config_defaultContextualSearchPackageName" translatable="false">com.google.android.googlequicksearchbox</string>
</resources>
```

`AndroidManifest.xml` untuk overlay:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.android.internal.overlay.cts"
    android:versionCode="1"
    android:versionName="1.0">
    <application android:hasCode="false" />
    <overlay
        android:targetPackage="android"
        android:priority="1000"
        android:isStatic="true" />
</manifest>
```

#### 1.2 Menambahkan System Feature XML (Wajib untuk Opsi di Launcher & Settings)
Launcher HyperOS (`MiuiHome` via `libapp_launcher.so`) dan Settings (`NavigationSettingsContextualSearchController`) memeriksa apakah sistem mendeklarasikan dua fitur:
1. `android.software.contextualsearch`
2. `com.google.android.feature.CONTEXTUAL_SEARCH`

Jika file permission ini tidak ada, toggle Circle to Search disembunyikan di menu navigasi launcher.

Buat file di `/product/etc/permissions/com.google.android.feature.CONTEXTUAL_SEARCH.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <feature name="android.software.contextualsearch" />
    <feature name="com.google.android.feature.CONTEXTUAL_SEARCH" />
</permissions>
```

---

### Langkah 2: Mem-bypass Permission di `services.jar`

Panggilan ke `startContextualSearch()` diverifikasi oleh `enforcePermission("android.permission.MANAGE_CONTEXTUAL_SEARCH")`. Kita harus mem-bypass pengecekan ini agar launcher atau app asisten dapat memanggilnya tanpa error `SecurityException`.

#### Modifikasi Smali (`services.jar`)
1. Deodex dan decompile `services.jar`:
   ```bash
   baksmali d services.jar -o services_out
   ```
2. Buka file:
   `services_out/com/android/server/contextualsearch/ContextualSearchManagerService.smali`
3. Cari method `enforcePermission`:
   ```smali
   .method private synchronized enforcePermission(Ljava/lang/String;)V
       .registers 4

       # TAMBAHKAN BARIS INI DI PALING ATAS METHOD:
       return-void

       # Kode asli di bawahnya biarkan saja
       ...
   .end method
   ```
4. Recompile smali kembali ke `services.jar` (simpan dengan kompresi uncompressed / STORED untuk dex).

---

### Langkah 3: Device Spoofing untuk Google App di `framework.jar`

Google App (AGSA) memeriksa properti `Build.BRAND`, `Build.MANUFACTURER`, dan `Build.MODEL`. Jika bukan Pixel/Samsung terpilih, fitur CTS tidak akan tampil. Kita perlu menyuntikkan spoofing level-framework khusus untuk package Google App.

#### Opsi A: Source Code (AOSP / Custom ROM)
Di `frameworks/base/core/java/android/app/Instrumentation.java` atau `ActivityThread.java`:

```java
public static void applyDeviceSpoofing(String packageName) {
    if ("com.google.android.googlequicksearchbox".equals(packageName)) {
        setBuildField("MANUFACTURER", "Google");
        setBuildField("BRAND", "google");
        setBuildField("MODEL", "Pixel 9 Pro");
        setBuildField("DEVICE", "caiman");
        setBuildField("PRODUCT", "caiman");
    }
}

private static void setBuildField(String key, String value) {
    try {
        Field field = Build.class.getDeclaredField(key);
        field.setAccessible(true);
        field.set(null, value);
    } catch (Exception ignored) {}
}
```

#### Opsi B: Patching Smali (`framework.jar`)
1. Decompile `framework.jar`:
   ```bash
   baksmali d framework.jar -o framework_out
   ```
2. Buka `framework_out/android/app/Application.smali` pada method `attach(Landroid/content/Context;)V`:
3. Sisipkan kode smali untuk menyetel nilai statis `Build`:
   ```smali
   # Ambil nama package saat ini
   invoke-virtual {p1}, Landroid/content/Context;->getPackageName()Ljava/lang/String;
   move-result-object v0
   const-string v1, "com.google.android.googlequicksearchbox"
   invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
   move-result v0
   if-eqz v0, :cond_skip_spoof

   # Set Build.MANUFACTURER = "Google"
   const-string v0, "Google"
   sput-object v0, Landroid/os/Build;->MANUFACTURER:Ljava/lang/String;

   # Set Build.BRAND = "google"
   const-string v0, "google"
   sput-object v0, Landroid/os/Build;->BRAND:Ljava/lang/String;

   # Set Build.MODEL = "Pixel 9 Pro"
   const-string v0, "Pixel 9 Pro"
   sput-object v0, Landroid/os/Build;->MODEL:Ljava/lang/String;

   # Set Build.DEVICE = "caiman"
   const-string v0, "caiman"
   sput-object v0, Landroid/os/Build;->DEVICE:Ljava/lang/String;

   # Set Build.PRODUCT = "caiman"
   const-string v0, "caiman"
   sput-object v0, Landroid/os/Build;->PRODUCT:Ljava/lang/String;

   :cond_skip_spoof
   ```

---

### Langkah 4: Mengalihkan Trigger Gesture Navigasi (White Bar)

Di HyperOS versi China atau Global, menahan gesture bar (white bar) mengirimkan intent `android.intent.action.ASSIST` ke package XiaoAi (`com.miui.voiceassist/com.xiaomi.voiceassistant.VoiceService`).

#### Metode Pilihan: Ganti XiaoAi dengan CTS Stub APK (Paling Bersih & Sangat Ringan)
Alih-alih mempertahankan APK XiaoAi asli yang berukuran raksasa (~250 MB) dan boros RAM:
1. Buat APK pengganti bernama **`VoiceAssistAndroidT.apk`** berukuran sangat kecil (**~1.9 MB** termasuk signature block asli).
2. **Pertahankan Signature Asli Xiaomi (`[6c02dd51]`):**
   - **PENTING:** Jangan di-sign menggunakan `testkey.keystore` karena akan ditolak oleh SELinux (`mac_permissions.xml`).
   - Ekstrak direktori `META-INF/` dan APK Signing Block 42 dari `VoiceAssistAndroidT.apk` bawaan Xiaomi, lalu suntikkan ke APK stub via script `scripts/inject_xiaomi_sig.py`.
3. **Kompatibilitas HyperOS Launcher (`MiuiHome` via `libapp_launcher.so`):**
   - Tambahkan metadata di `<application>` `AndroidManifest.xml`:
     - `xiaoai.supportGestureLineWakeUp` = `true` (memunculkan opsi garis gestur di launcher)
     - `ShortcutKeyWakeUpVersion` = `4`
     - `xiaoai.ShortcutKeyWakeUpVersion` = `2`
     - `is_super_ai` = `true`
   - Sediakan dummy `GlobalContentProvider` (`com.miui.voiceassist.contentprovider.GlobalContentProvider`) yang merespons panggilan method `getRecordAreaHeight` (mengembalikan integer `record_area_height_px`).
   - Sediakan activity dummy `GestureLineWakeUpSettingsActivity` & `GestureLineWakeUpSettingsActivityV2`.
4. **Penanganan Foreground Service (Anti-Crash Android 14):**
   - Karena launcher memanggil `VoiceService` via `startForegroundServiceAsUser`, method `VoiceService.onStartCommand()` **wajib** segera memanggil `startForeground()` sebelum memicu CTS, lalu memanggil `stopForeground(1)` dan `stopSelf()`. Hal ini mencegah ART melempar fatal exception `ForegroundServiceDidNotStartInTimeException`.
5. Pada `onStartCommand()`, panggil `contextual_search` secara langsung melalui raw Binder transact (code 3, entrypoint 1) dengan debounce 1 detik:
   ```smali
   const-string v0, "contextual_search"
   invoke-static {v0}, Landroid/os/ServiceManager;->getService(Ljava/lang/String;)Landroid/os/IBinder;
   move-result-object v0
   if-nez v0, :cond_cs_found
   return-void

   :cond_cs_found
   invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
   move-result-object v1
   const-string v4, "android.app.contextualsearch.IContextualSearchManager"
   invoke-virtual {v1, v4}, Landroid/os/Parcel;->writeInterfaceToken(Ljava/lang/String;)V
   const/4 v2, 0x1
   invoke-virtual {v1, v2}, Landroid/os/Parcel;->writeInt(I)V   # entrypoint = 1
   const/4 v5, 0x0
   invoke-virtual {v1, v5}, Landroid/os/Parcel;->writeInt(I)V   # config = null (0)
   const/4 v4, 0x3
   invoke-interface {v0, v4, v1, v3, v2}, Landroid/os/IBinder;->transact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
   invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V
   ```
6. **Keuntungan:**
   - **Hemat Ruang ROM:** Ukuran terpangkas dari 250 MB menjadi ~1.9 MB.
   - **Hemat RAM & Baterai:** Tidak ada background service bloat XiaoAi (`:core`, `:pushservice`, `:remote`).
   - **Drop-in Replacement:** Cukup timpa file `/product/priv-app/VoiceAssistAndroidT/VoiceAssistAndroidT.apk` di folder ROM saat proses repacking.

> [!TIP]
> **Modul & File Binary Siap Pakai:**
> - [prebuilt/VoiceAssistCTS.apk](prebuilt/VoiceAssistCTS.apk) (~1.9 MB): APK stub siap pakai yang sudah disuntikkan signature asli Xiaomi platform.
> - [prebuilt/VoiceAssistCTS-Magisk.zip](prebuilt/VoiceAssistCTS-Magisk.zip) (~801 KB): Modul flashable Magisk / KernelSU untuk menggantikan XiaoAi secara systemless.
> - [prebuilt/CTSConfigOverlay.apk](prebuilt/CTSConfigOverlay.apk) (~3.5 KB): APK RRO untuk config package contextual search pada `framework-res`.
> - [prebuilt/CTSConfigOverlay-Magisk.zip](prebuilt/CTSConfigOverlay-Magisk.zip) (~4.0 KB): Modul Magisk / KernelSU untuk overlay RRO + XML permissions.

---

### Langkah 5: Konfigurasi Default Settings Database

Pastikan asisten default, gesture bar setting, dan hak akses screenshot/struktur layar diizinkan secara default saat first-boot.

Tambahkan pada `frameworks/base/packages/SettingsProvider/res/values/defaults.xml` (atau via command / overlay SettingsProvider):

```xml
<!-- Mengarahkan aksi Long Press Navigation Bar ke VoiceAssistant -->
<string name="def_nav_long_press" translatable="false">VoiceAssistant</string>

<!-- Mengarahkan asisten ke Google VoiceInteractionService -->
<string name="def_assistant" translatable="false">com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService</string>
<string name="def_voice_interaction_service" translatable="false">com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService</string>
<string name="def_voice_recognition_service" translatable="false">com.google.android.googlequicksearchbox/com.google.android.voicesearch.serviceapi.GoogleRecognitionService</string>

<!-- Mengizinkan pengiriman konteks layar & tangkapan layar untuk analisis pencarian -->
<bool name="def_assist_structure_enabled">true</bool>
<bool name="def_assist_screenshot_enabled">true</bool>
```

---

### Pengujian & Verifikasi via ADB

Setelah ROM di-flash atau file sistem diganti, lakukan verifikasi berikut melalui terminal ADB:

1. **Pastikan service `contextual_search` aktif di system_server:**
   ```bash
   adb shell service list | grep contextual_search
   ```
   *Output yang diharapkan:*
   ```text
   contextual_search: [android.app.contextualsearch.IContextualSearchManager]
   ```

2. **Periksa spoofing Build pada Google App:**
   ```bash
   adb shell "dumpsys package com.google.android.googlequicksearchbox | grep -i version"
   ```

3. **Uji coba trigger Contextual Search secara manual melalui IPC:**
   ```bash
   adb shell cmd contextual_search start 1
   ```

4. **Uji coba Long Press Gesture Bar:**
   - Tahan garis navigasi di bawah layar.
   - Layar bergetar sedikit dan memunculkan animasi shimmer / lingkaran pencarian Google App (Circle to Search).
