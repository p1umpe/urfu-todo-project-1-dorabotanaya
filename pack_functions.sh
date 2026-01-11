#!/bin/bash
# Исправленный скрипт для упаковки Cloud Functions в ZIP архивы

set -e

echo "=== Упаковка Cloud Functions ==="

# Проверяем, что мы в правильной директории
if [ ! -d "functions" ]; then
    echo "ОШИБКА: Папка functions не найдена в текущей директории"
    echo "Запустите скрипт из корня проекта (urfu-todo-project-1/)"
    exit 1
fi

cd functions

# Список функций для упаковки (исключая common)
FUNCTIONS=("create_task" "delete_task" "get_tasks" "update_task")

# Для каждой функции создаем ZIP архив
for func_name in "${FUNCTIONS[@]}"; do
    echo "Упаковка функции: $func_name"
    
    # Проверяем существование директории
    if [ ! -d "$func_name" ]; then
        echo "  ОШИБКА: папка $func_name не найдена"
        continue
    fi
    
    # Переходим в директорию функции
    cd $func_name
    
    echo "  Текущая директория: $(pwd)"
    echo "  Файлы: $(ls -la)"
    
    # Создаем временную директорию для упаковки
    mkdir -p /tmp/$func_name
    
    # Копируем файлы функции
    if [ -f "index.py" ]; then
        cp index.py /tmp/$func_name/
    else
        echo "  ВНИМАНИЕ: index.py не найден в $func_name"
    fi
    
    if [ -f "requirements.txt" ]; then
        cp requirements.txt /tmp/$func_name/
    else
        echo "  ВНИМАНИЕ: requirements.txt не найден в $func_name"
    fi
    
    # Копируем общий модуль
    if [ -d "../common" ]; then
        mkdir -p /tmp/$func_name/common
        cp ../common/ydb_client.py /tmp/$func_name/common/
    fi
    
    # Создаем ZIP архив
    cd /tmp/$func_name
    zip -r "$OLDPWD/../$func_name.zip" . > /dev/null 2>&1
    
    # Возвращаемся обратно
    cd "$OLDPWD/.."
    
    if [ -f "$func_name.zip" ]; then
        echo "  -> Создан архив: $func_name.zip (размер: $(stat -f%z "$func_name.zip") байт)"
    else
        echo "  -> ОШИБКА: архив не создан"
    fi
done

echo "=== Готово! Все функции упакованы ==="
echo "Архивы находятся в папке functions/"