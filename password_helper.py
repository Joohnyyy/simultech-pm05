import hashlib
import secrets

class PasswordHelper:
    @staticmethod
    def generate_salt() -> str:
        """Генерирует случайную соль: 16 байт → hex-строка (32 символа)."""
        return secrets.token_hex(16)

    @staticmethod
    def hash_password(password: str, salt: str) -> str:
        """Вычисляет SHA-256 хэш от (соль + пароль). Возвращает hex-строку (64 символа)."""
        return hashlib.sha256((salt + password).encode()).hexdigest()

    @staticmethod
    def verify_password(password: str, salt: str, stored_hash: str) -> bool:
        """Проверяет введённый пароль: сравнивает хэши."""
        return PasswordHelper.hash_password(password, salt) == stored_hash