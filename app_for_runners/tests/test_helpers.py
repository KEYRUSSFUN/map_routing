import os
import sys

from colorama import Fore, Style, init as colorama_init

colorama_init()


def _supports_ansi() -> bool:
    # Включаем цвета всегда, чтобы вывод был "зелёным".
    # (У пользователя может быть NO_COLOR=1 в окружении, но это нам не нужно.)
    return True


def _color(text: str, color_code: str) -> str:
    if not _supports_ansi():
        return text
    color = Fore.GREEN if color_code == "32" else Fore.RED
    return f"{color}{text}{Style.RESET_ALL}"


def assert_status(resp, expected: int, label: str):
    actual = getattr(resp, "status_code", None)
    line = f"{label} -> expected {expected} got {actual}"
    if actual == expected:
        line = _color(line, "32")  # green
    else:
        line = _color(line, "31")  # red
    print(line)
    assert actual == expected

