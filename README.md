# ReadingMaster（阅读王）

AI 英语分级阅读产品。MVP 采用 **Flutter Web-first + FastAPI**：先用网页版在 iPad Safari / Chrome 上验证，Android 真机后续验证通过后再生成 APK。

## 当前阶段

Phase 0：项目初始化，仅打通本地开发、测试和基础健康检查。

## 目录

```text
apps/
  mobile/    Flutter Web-first 项目
  backend/   FastAPI 项目
docs/        产品与技术文档
```

## 本地开发

### 后端

```powershell
cd apps/backend
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
```

访问 `http://localhost:8000/health`，应返回：

```json
{"status":"ok"}
```

### Flutter Web

```powershell
cd apps/mobile
flutter pub get
flutter run -d chrome
```

构建网页产物：

```powershell
flutter build web
```

### Docker Compose

安装并启动 Docker Desktop 后：

```powershell
docker compose up --build
```

后端仍通过 `http://localhost:8000/health` 验证。

## 测试

```powershell
cd apps/backend
.\.venv\Scripts\python.exe -m pytest
```

```powershell
cd apps/mobile
flutter test
flutter analyze
```
