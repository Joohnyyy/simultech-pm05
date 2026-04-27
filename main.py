import json, secrets
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from typing import List

DATABASE_URL = "postgresql+psycopg2://postgres:postgres@localhost:5432/simultech"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

app = FastAPI(title="Симултех (упрощённый режим)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class CheckoutItem(BaseModel):
    product_id: int
    quantity: int

class CheckoutRequest(BaseModel):
    items: List[CheckoutItem]
    payment_method: str = "cash"

@app.post("/register")
def register(login: str, password: str, role: str, db: Session = Depends(get_db)):
    if db.execute(text("SELECT 1 FROM users WHERE login=:login"), {"login": login}).first():
        raise HTTPException(400, "Логин занят")
    db.execute(text("INSERT INTO users (login, password_hash, role) VALUES (:login, :pass, :role)"),
               {"login": login, "pass": password, "role": role})
    db.commit()
    return {"status": "registered"}

@app.post("/login")
def login(login: str, password: str, db: Session = Depends(get_db)):
    user = db.execute(text("SELECT id, role FROM users WHERE login=:login AND password_hash=:pass"),
                      {"login": login, "pass": password}).fetchone()
    if not user:
        raise HTTPException(401, "Неверные данные")
    return {"access_token": "fake-token", "role": user.role}

@app.get("/api/checks")
def get_checks(db: Session = Depends(get_db)):
    rows = db.execute(text("""
        SELECT ch.id AS check_id, ch.fiscal_number, u.login AS cashier,
               ch.date_time, ch.total, ch.payment_type,
               pr.name AS product, ci.quantity, ci.price_at_moment
        FROM checks ch
        JOIN users u ON ch.cashier_id = u.id
        JOIN check_items ci ON ch.id = ci.check_id
        JOIN products pr ON ci.product_id = pr.id
        ORDER BY ch.date_time DESC
    """)).fetchall()
    return [dict(row._mapping) for row in rows]

@app.post("/api/checkout")
def checkout(req: CheckoutRequest, db: Session = Depends(get_db)):
    cashier_id = 1
    total = 0.0

    for item in req.items:
        prod = db.execute(text("SELECT price, stock FROM products WHERE id=:id"), {"id": item.product_id}).fetchone()
        if not prod:
            raise HTTPException(status_code=400, detail=f"Товар с id={item.product_id} не найден")
        if prod.stock < item.quantity:
            raise HTTPException(status_code=400, detail=f"Недостаточно товара id={item.product_id}")
        total += prod.price * item.quantity

    fiscal = "FN-" + secrets.token_hex(4)

    # Вставляем чек с уникальным фискальным номером
    db.execute(
        text("INSERT INTO checks (fiscal_number, cashier_id, date_time, total, payment_type) VALUES (:fn, :cid, NOW(), :total, :pt)"),
        {"fn": fiscal, "cid": cashier_id, "total": total, "pt": req.payment_method}
    )

    # Получаем id чека по фискальному номеру (гарантированно уникален)
    check_id = db.execute(text("SELECT id FROM checks WHERE fiscal_number = :fn"), {"fn": fiscal}).scalar()

    # Вставляем позиции и обновляем остатки
    for item in req.items:
        price = db.execute(text("SELECT price FROM products WHERE id=:id"), {"id": item.product_id}).scalar()
        db.execute(
            text("INSERT INTO check_items (check_id, product_id, quantity, price_at_moment) VALUES (:cid, :pid, :qty, :price)"),
            {"cid": check_id, "pid": item.product_id, "qty": item.quantity, "price": price}
        )
        db.execute(
            text("UPDATE products SET stock = stock - :qty WHERE id = :pid"),
            {"qty": item.quantity, "pid": item.product_id}
        )

    db.commit()
    return {"status": "success", "message": f"Чек №{check_id} создан", "check_id": check_id}

@app.put("/api/checks/{check_id}/payment")
def update_payment(check_id: int, payment_type: str, db: Session = Depends(get_db)):
    db.execute(text("UPDATE checks SET payment_type = :pt WHERE id = :id"), {"pt": payment_type, "id": check_id})
    db.commit()
    return {"status": "updated"}

@app.delete("/api/checks/{check_id}")
def delete_check(check_id: int, db: Session = Depends(get_db)):
    db.execute(text("DELETE FROM check_items WHERE check_id = :id"), {"id": check_id})
    db.execute(text("DELETE FROM checks WHERE id = :id"), {"id": check_id})
    db.commit()
    return {"status": "deleted"}

@app.get("/api/products")
def search_products(q: str, db: Session = Depends(get_db)):
    rows = db.execute(text("SELECT id, name, price, stock FROM products WHERE name ILIKE :q LIMIT 10"),
                      {"q": f"%{q}%"}).fetchall()
    return [dict(row._mapping) for row in rows]

@app.get("/api/reports/csv")
def reports_csv(db: Session = Depends(get_db)):
    rows = db.execute(text("""
        SELECT ch.fiscal_number, u.login AS cashier, ch.date_time, ch.total,
               pr.name AS product, ci.quantity, ci.price_at_moment
        FROM checks ch
        JOIN users u ON ch.cashier_id = u.id
        JOIN check_items ci ON ch.id = ci.check_id
        JOIN products pr ON ci.product_id = pr.id
        ORDER BY ch.date_time DESC
    """)).fetchall()
    csv_lines = ["fiscal_number;cashier;date_time;total;product;quantity;price"]
    for r in rows:
        csv_lines.append(f"{r.fiscal_number};{r.cashier};{r.date_time};{r.total};{r.product};{r.quantity};{r.price_at_moment}")
    csv_text = "\n".join(csv_lines)
    return PlainTextResponse(content=csv_text, media_type="text/csv",
                             headers={"Content-Disposition": "attachment; filename=report.csv"})