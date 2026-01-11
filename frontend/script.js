const API_BASE_URL = 'https://d5dg42412mornb62haj2.pdkwbi1w.apigw.yandexcloud.net';

document.addEventListener('DOMContentLoaded', function() {
    loadTasks();
});

async function apiRequest(url, options = {}) {
    const response = await fetch(url, {
        headers: {
            'Content-Type': 'application/json',
            ...options.headers
        },
        ...options
    });
    
    if (!response.ok) {
        const error = await response.text();
        throw new Error(`HTTP ${response.status}: ${error}`);
    }
    
    return response.json();
}

async function loadTasks() {
    try {
        const data = await apiRequest(`${API_BASE_URL}/tasks?status=all`);
        renderTasks(data.tasks || []);
    } catch (error) {
        console.error('Ошибка загрузки задач:', error);
        alert('Не удалось загрузить задачи');
    }
}

function renderTasks(tasks) {
    const list = document.getElementById('taskList');
    if (!list) return;
    
    list.innerHTML = '';
    
    if (tasks.length === 0) {
        list.innerHTML = '<li style="text-align: center; color: #777;">Нет задач. Добавьте первую!</li>';
        return;
    }
    
    tasks.forEach(task => {
        const li = document.createElement('li');
        li.dataset.id = task.id;
        
        li.innerHTML = `
            <input type="checkbox" ${task.status === 'completed' ? 'checked' : ''} 
                onchange="toggleComplete('${task.id}', this.checked)" />
            <span class="${task.status === 'completed' ? 'completed' : ''}">${task.title}</span>
            <button class="edit-btn" onclick="editTaskPrompt('${task.id}', '${escapeHtml(task.title)}')">✎</button>
            <button class="delete-btn" onclick="deleteTask('${task.id}')">🗑️</button>
        `;
        list.appendChild(li);
    });
}

function escapeHtml(text) {
    return text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

async function addTask() {
    const input = document.getElementById('taskInput');
    const title = input.value.trim();
    
    if (!title) {
        alert('Введите название задачи');
        return;
    }
    
    try {
        await apiRequest(`${API_BASE_URL}/tasks`, {
            method: 'POST',
            body: JSON.stringify({
                title: title,
                description: ''
            })
        });
        
        input.value = '';
        loadTasks();
    } catch (error) {
        console.error('Ошибка создания:', error);
        alert('Не удалось создать задачу');
    }
}

async function toggleComplete(id, completed) {
    try {
        await apiRequest(`${API_BASE_URL}/tasks/${id}`, {
            method: 'PUT',
            body: JSON.stringify({
                status: completed ? 'completed' : 'active'
            })
        });
        
        loadTasks();
    } catch (error) {
        console.error('Ошибка обновления:', error);
        alert('Не удалось обновить статус');
    }
}

async function editTaskPrompt(id, currentTitle) {
    const newTitle = prompt('Новое название:', currentTitle);
    if (newTitle !== null && newTitle.trim() !== '') {
        try {
            await apiRequest(`${API_BASE_URL}/tasks/${id}`, {
                method: 'PUT',
                body: JSON.stringify({
                    title: newTitle.trim()
                })
            });
            
            loadTasks();
        } catch (error) {
            console.error('Ошибка редактирования:', error);
            alert('Не удалось обновить задачу');
        }
    }
}

async function deleteTask(id) {
    if (!confirm('Удалить задачу?')) return;
    
    try {
        await apiRequest(`${API_BASE_URL}/tasks/${id}`, {
            method: 'DELETE'
        });
        
        loadTasks();
    } catch (error) {
        console.error('Ошибка удаления:', error);
        alert('Не удалось удалить задачу');
    }
}

// Экспортируем функции в глобальную область видимости
window.addTask = addTask;
window.toggleComplete = toggleComplete;
window.editTaskPrompt = editTaskPrompt;
window.deleteTask = deleteTask;
window.loadTasks = loadTasks;

document.getElementById('taskInput').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') addTask();
});