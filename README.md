# ReadingMaster（阅读王）

AI 英语分级阅读产品。MVP 采用 **Flutter Web-first + FastAPI**：先用网页版在 iPad Safari / Chrome 上验证，Android 真机后续验证通过后再生成 APK。

## 当前阶段

Phase 4：阅读核心闭环已打通，包含事件记录、quiz 更新和端到端集成测试。

## 目录

```text
apps/
  mobile/    Flutter Web-first 项目
  backend/   FastAPI + SQLAlchemy + Alembic
database/    迁移与 seed 相关脚本
docs/        产品与技术文档
```

## 本地开发

### 后端

```powershell
cd apps/backend
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

本地运行时，后端从仓库根目录的 `.env` 读取 `DATABASE_URL`，默认连接：

```text
localhost:5432
```

启动后端：

```powershell
uvicorn app.main:app --reload
```

访问：

```text
Swagger: http://localhost:8000/docs
Health:  http://localhost:8000/health
```

### 数据库迁移

```powershell
cd apps/backend
.\.venv\Scripts\python.exe -m alembic upgrade head
```

### Seed 数据

```powershell
cd apps/backend
.\.venv\Scripts\python.exe -m app.db.seed
```

默认测试账号：

```text
test@example.com
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

后端容器启动时会自动执行 `alembic upgrade head`。容器内后端使用服务名 `postgres` 访问数据库，而不是 `localhost`。

## 已实现 API

所有业务接口统一使用 `/api/v1` 前缀：

```text
POST /auth/register
POST /auth/login
GET  /children
POST /children
GET  /home
GET  /books
GET  /books/{book_id}
GET  /books/{book_id}/quiz
GET  /words/{word}
POST /reading/sessions
POST /reading/events
POST /reading/sessions/{session_id}/finish
POST /quiz/attempt
GET  /children/{child_id}/words
```

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
