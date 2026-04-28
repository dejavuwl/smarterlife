# SmarterLife MVP

一个轻量化的饮食 + 健身 + 动态热量目标管理应用，包含：

- `flutter_app/`：Flutter 客户端
- `backend/`：Rust + Axum 的 Cloud Run API

## Firestore 结构

```text
users/{userId}
  heightCm: number
  currentWeightKg: number
  startWeightKg: number
  targetWeightKg: number
  targetDays: number
  age: number | null
  gender: "male" | "female" | null
  planStartDate: "YYYY-MM-DD"
  createdAt: timestamp string
  updatedAt: timestamp string

users/{userId}/dailyStats/{date}
  date: "YYYY-MM-DD"
  meals: [
    {
      name: string
      caloriesPerUnit: number
      quantity: number
      totalCalories: number
      loggedAt: timestamp string
    }
  ]
  workouts: [
    {
      type: string
      durationMinutes: number
      intensity: "low" | "medium" | "high"
      estimatedCaloriesBurned: number
      loggedAt: timestamp string
    }
  ]
  caloriesConsumed: number
  caloriesBurned: number
  latestWeightKg: number | null
  updatedAt: timestamp string

users/{userId}/weightHistory/{autoId}
  weightKg: number
  recordedAt: timestamp string
  source: "setup" | "manual_update"
```

## Firestore 安全规则

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Flutter 部署和运行

1. 安装 Flutter SDK、Android Studio 或 Xcode。
2. 在 Firebase 控制台创建 iOS / Android App，并添加原生配置文件：
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
3. 启用 Firebase Auth 提供商：
   - Anonymous
   - Email/Password
   - Google
   - Apple
4. 进入 [flutter_app](./flutter_app) 执行：

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://YOUR_CLOUD_RUN_URL
```

## Cloud Run 部署

1. 设置环境变量：

```bash
gcloud config set project YOUR_PROJECT_ID
```

2. 确保 Cloud Run 服务账号拥有以下权限：
   - `Cloud Datastore User`
   - `Service Account Token Creator`（若你的组织策略要求）

3. 部署：

```bash
cd backend
gcloud run deploy smarterlife-api ^
  --source . ^
  --region asia-east1 ^
  --allow-unauthenticated ^
  --set-env-vars GCP_PROJECT=YOUR_PROJECT_ID,FIREBASE_API_KEY=YOUR_FIREBASE_WEB_API_KEY
```

## Cloud Run API

- `POST /setupUser`
- `POST /addMeal`
- `POST /addWorkout`
- `POST /updateWeight`
- `POST /dailySummary`
- `POST /recommendation`

每个请求都需要：

```http
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json
```

## 动态热量目标逻辑

- BMR 使用简化版 Mifflin-St Jeor 公式
- TDEE = `BMR * 1.4`
- 每日热量缺口 = `剩余需减重 * 7700 / 剩余目标天数`
- 如果当前减重慢于计划约 `0.4kg` 以上：
  - `/recommendation` 返回 `overweight_adjusted`
  - 自动收紧当日热量目标并建议补充运动
- 如果当天已经超出热量预算：
  - 返回 `deficit`
- 其他情况：
  - 返回 `balanced`
