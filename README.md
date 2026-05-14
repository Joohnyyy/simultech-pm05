 Производственная практика ПМ.05 - Симултех

Информационная система автоматизации процесса розничной продажи для аптеки ООО «Симултех».

 Стек технологий
- СУБД: PostgreSQL
- Бэкенд: Python, FastAPI, SQLAlchemy
- Фронтенд: Vue.js, Bootstrap 5
- Инструменты: pgAdmin, Swagger, Git, GitHub

 Структура репозитория
- `backend/` – серверная часть приложения
  - `main.py` – основной файл API (FastAPI)
  - `frontend.html` – клиентская часть (Vue.js + Bootstrap)
- `sql/` – SQL-скрипты
  - `ddl.sql` – создание таблиц базы данных
  - `dml.sql` – тестовые данные (INSERT)
  - `views_procedures_triggers.sql` – представления, хранимые процедуры, триггеры
- `screenshots/` – скриншоты интерфейса и результатов тестирования

 Локальный запуск

 1. Установка зависимостей
```bash
pip install fastapi uvicorn sqlalchemy psycopg2-binary
