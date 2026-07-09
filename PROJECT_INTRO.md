# 專題介紹：Memory Assistant

## 一、專題概述

Memory Assistant 是一款以 Flutter 開發的 Android 行動應用程式，主要目標是協助需要日常提醒、記憶輔助與照護支持的使用者。系統結合任務管理、AI 陪伴、語音互動、情緒紀錄、回憶相簿、定位分享與照護者管理功能，讓使用者能透過手機完成每日生活安排，也讓照護者能更即時掌握被照護者的任務狀態與安全資訊。

本專題不是單純的行事曆，也不是單純的聊天機器人，而是將「日常任務」、「AI 對話」、「語音輸入輸出」、「回憶紀錄」與「照護者監測」整合在同一個 App 中，形成一套較完整的記憶照護輔助流程。

## 二、開發平台與目標

本專題採用 Flutter 作為跨平台開發框架，但目前主要開發與測試重心放在 Android 平台。Android 端使用多項原生能力，例如背景排程、精準鬧鐘、本機通知、定位權限、Google Maps 與語音相關功能。

主要目標平台：

- Android 手機
- Android 模擬器
- 可延伸至 iOS、Web、Windows、macOS、Linux，但目前核心功能以 Android 為主

## 三、主要功能

### 1. 使用者登入與角色分流

系統使用 Firebase Authentication 進行帳號註冊與登入。登入後會依照 Firestore 中的角色資料分流至一般使用者或照護者流程。

一般使用者可進入主選單、任務管理、AI 陪伴、回憶相簿與個人資料頁面。照護者則可以綁定被照護者、選擇照護對象、查看任務狀態與定位地圖。

### 2. 任務與行程管理

使用者可以建立每日任務，任務資料儲存在 Firestore 的使用者子集合中。任務資料包含日期、開始時間、結束時間、任務類型、完成狀態與建立時間。

系統也支援語音輸入，使用者可以透過說話建立行程，並由 Gemini API 協助解析語音內容中的日期、時間與任務資訊。

### 3. AI 陪伴功能

AI 陪伴頁面提供聊天式互動，系統會根據使用者輸入、當日任務、情緒紀錄與回憶資料產生回應。AI 回應可透過文字顯示，也可使用 TTS 朗讀，提升對長者或需要語音輔助者的友善度。

AI 陪伴服務也會讀取今日任務，產生提醒文字，協助使用者知道接下來要做什麼。

### 4. 語音互動

本專題使用 `speech_to_text` 實作語音轉文字，讓使用者可以用自然語音輸入任務或與系統互動。使用 `flutter_tts` 將 AI 回覆轉換成語音播放，形成更接近陪伴式的互動體驗。

### 5. 情緒紀錄

使用者每天可進行情緒打卡，系統會將情緒與備註儲存在 Firestore。完成情緒紀錄後，App 可引導使用者進入 AI 陪伴頁面，讓 AI 根據當下情緒給予簡短回應或陪伴式對話。

### 6. 回憶相簿

回憶相簿模組可保存照片、文字與音訊等個人回憶資料。系統支援新增、編輯與管理回憶，也可透過 Cloudinary 或 Firebase 相關服務上傳媒體檔案。

AI 陪伴服務可在對話中嘗試比對回憶內容，並播放相關回憶音訊，強化記憶喚起與陪伴感。

### 7. 本機通知與背景提醒

系統使用 `flutter_local_notifications` 建立本機通知，並透過 Android exact alarm 與 `android_alarm_manager_plus` 實作背景提醒。App 可在早上與晚上觸發 AI 提醒，或在任務即將開始時提醒使用者。

Android Manifest 中已加入通知、鬧鐘、Wake Lock、Foreground Service 等權限，以支援背景提醒情境。

### 8. 定位與照護者地圖

當使用者開啟定位分享時，`LocationUploader` 會將目前位置更新到 Firestore。照護者可以透過 Google Maps 查看被照護者的位置，並搭配安全區域設定進行照護輔助。

## 四、技術架構

### 前端技術

- Flutter：跨平台 UI 開發框架
- Dart：主要開發語言
- Material Design：介面元件與視覺風格

### 雲端與資料服務

- Firebase Authentication：使用者註冊、登入與身份管理
- Cloud Firestore：儲存使用者、任務、照護者、AI 對話、情緒與回憶資料
- Firebase Storage：支援雲端檔案儲存情境
- Cloudinary API：媒體檔案上傳
- Gemini API：AI 對話、任務語意解析與陪伴式回應

### Android 與裝置能力

- `flutter_local_notifications`：本機通知
- `android_alarm_manager_plus`：Android 背景排程
- `permission_handler`：權限請求與檢查
- `speech_to_text`：語音轉文字
- `flutter_tts`：文字轉語音
- `geolocator`：定位取得
- `geocoding`：地理編碼
- `google_maps_flutter`：Google 地圖顯示
- `image_picker`、`file_picker`：圖片與檔案選取
- `record`、`just_audio`：音訊錄製與播放
- `flutter_dotenv`：讀取本機環境變數

## 五、資料設計概念

系統以 Firebase 作為主要後端服務。常見資料集合包含：

- `users`：使用者基本資料、角色、定位設定與位置資訊
- `users/{uid}/tasks`：個別使用者的任務資料
- `caregivers`：照護者資料與綁定關係
- `memories`：回憶相簿資料
- `ai_companion`：AI 對話紀錄
- mood-related records：每日情緒紀錄

任務資料通常包含：

```json
{
  "task": "吃藥",
  "time": "09:00",
  "end": "09:30",
  "type": "健康",
  "completed": false,
  "date": "2026-07-09",
  "createdAt": "server timestamp"
}
```

## 六、系統特色

- 以 Android 實機功能為核心，包含通知、定位、背景排程與語音互動
- 將 AI 對話與任務資料結合，不只是一般聊天功能
- 支援照護者與被照護者雙角色流程
- 透過情緒紀錄與回憶相簿強化陪伴與記憶輔助
- 使用 Firebase 降低後端建置成本，快速完成身份、資料與雲端同步功能
- 使用 Gemini API 進行自然語言理解與回應生成

## 七、專題價值

Memory Assistant 的價值在於把日常照護中分散的需求整合到單一 App：提醒使用者完成任務、透過語音降低操作門檻、使用 AI 提供陪伴式回應、保存重要回憶資料，並讓照護者可以掌握被照護者的基本狀態。對需要記憶輔助或照護支持的使用者而言，這樣的系統能提供更貼近日常生活的行動輔助。
