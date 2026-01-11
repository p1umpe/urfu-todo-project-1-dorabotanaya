#!/bin/bash
# Скрипт для загрузки фронтенда в Object Storage

set -e

echo "=== Загрузка фронтенда в Object Storage ==="

# Получаем данные из terraform outputs
cd terraform
BUCKET_NAME=$(terraform output -raw bucket_name)
ACCESS_KEY=$(terraform output -raw storage_access_key 2>/dev/null || echo "")
SECRET_KEY=$(terraform output -raw storage_secret_key 2>/dev/null || echo "")

if [ -z "$BUCKET_NAME" ]; then
    echo "ОШИБКА: Не удалось получить bucket_name"
    exit 1
fi

echo "Бакет: $BUCKET_NAME"
echo "URL сайта: https://${BUCKET_NAME}.website.yandexcloud.net"

cd ../frontend

# Проверяем файлы
echo "Файлы для загрузки:"
ls -la

# Способ 1: Используем yc (проще)
echo "Загрузка через yc..."
for file in *; do
    if [ -f "$file" ]; then
        echo "Загрузка: $file"
        yc storage s3 cp "$file" "s3://${BUCKET_NAME}/${file}" --acl public-read
    fi
done

echo "=== Готово! ==="
echo "Фронтенд доступен по адресу:"
echo "https://${BUCKET_NAME}.website.yandexcloud.net"
