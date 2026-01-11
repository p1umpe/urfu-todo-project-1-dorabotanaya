#!/bin/bash
# Подключаемся к ВМ через yc (если есть доступ)
echo "Проверяем конфигурацию nginx..."

# Сначала проверим что работает на ВМ
curl -v http://localhost/health 2>&1 | head -20
echo "---"
curl -v http://localhost/tasks 2>&1 | head -30
