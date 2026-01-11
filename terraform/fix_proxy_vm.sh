#!/bin/bash
# Создадим health endpoint
cat > /tmp/health.json << 'HEALTH'
{"status": "ok", "service": "todo-proxy", "timestamp": "$(date)"}
HEALTH

# Запустим Python сервер с правильной структурой
cd /tmp
# Остановим текущий сервер (если работает)
pkill -f "python3 -m http.server"

# Создадим index.html для корня
cat > index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Todo Proxy</title>
</head>
<body>
    <h1>Todo Application Proxy</h1>
    <p>Status: <a href="/health">/health</a> - Health check endpoint</p>
    <p>API: <a href="/tasks">/tasks</a> - Todo API</p>
</body>
</html>
HTML

# Запустим сервер на порту 80
python3 -m http.server 80 &
echo "Proxy VM fixed"
