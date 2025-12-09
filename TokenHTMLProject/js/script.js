// Конфигурация
const API_BASE_URL = 'http://localhost:5261';
let currentToken = localStorage.getItem('api_token') || '';

// Элементы DOM
const elements = {
    username: document.getElementById('username'),
    password: document.getElementById('password'),
    btnLogin: document.getElementById('btnLogin'),
    btnLogout: document.getElementById('btnLogout'),
    authStatus: document.getElementById('authStatus'),
    statusText: document.getElementById('statusText'),
    tokenPreview: document.getElementById('tokenPreview'),
    errorMessage: document.getElementById('errorMessage'),
    btnGetUserInfo: document.getElementById('btnGetUserInfo'),
    btnGetAdminData: document.getElementById('btnGetAdminData'),
    btnGetStats: document.getElementById('btnGetStats'),
    btnGetPublicInfo: document.getElementById('btnGetPublicInfo'),
    btnGetHealth: document.getElementById('btnGetHealth'),
    userData: document.getElementById('userData'),
    adminData: document.getElementById('adminData'),
    statsData: document.getElementById('statsData'),
    publicData: document.getElementById('publicData'),
    logs: document.getElementById('logs'),
    btnClearLogs: document.getElementById('btnClearLogs'),
    btnRunTests: document.getElementById('btnRunTests'),
    tabButtons: document.querySelectorAll('.tab-btn'),
    tabPanes: document.querySelectorAll('.tab-pane')
};

// Утилиты
function log(message, type = 'info') {
    console.log(`[${type.toUpperCase()}] ${message}`);
    const timestamp = new Date().toLocaleTimeString();
    const logEntry = document.createElement('div');
    logEntry.className = `log-entry ${type}`;
    logEntry.innerHTML = `<span class="time">[${timestamp}]</span> ${message}`;
    elements.logs.prepend(logEntry);
    
    // Сохраняем в localStorage
    const logs = JSON.parse(localStorage.getItem('api_logs') || '[]');
    logs.unshift({ time: timestamp, message, type });
    if (logs.length > 50) logs.length = 50;
    localStorage.setItem('api_logs', JSON.stringify(logs));
}

function showError(message) {
    console.error('Error:', message);
    elements.errorMessage.textContent = message;
    elements.errorMessage.classList.remove('hidden');
    log(message, 'error');
}

function showSuccess(message) {
    console.log('Success:', message);
    log(message, 'success');
}

function updateUI() {
    console.log('Updating UI, token exists:', !!currentToken);
    
    if (currentToken) {
        elements.btnLogin.disabled = true;
        elements.btnLogout.disabled = false;
        elements.btnGetUserInfo.disabled = false;
        elements.btnGetAdminData.disabled = false;
        elements.btnGetStats.disabled = false;
        elements.authStatus.classList.remove('hidden');
        elements.statusText.textContent = 'Авторизован';
        elements.tokenPreview.textContent = `${currentToken.substring(0, 20)}...`;
    } else {
        elements.btnLogin.disabled = false;
        elements.btnLogout.disabled = true;
        elements.btnGetUserInfo.disabled = true;
        elements.btnGetAdminData.disabled = true;
        elements.btnGetStats.disabled = true;
        elements.authStatus.classList.add('hidden');
        elements.errorMessage.classList.add('hidden');
    }
}

// Загрузка логов
function loadLogs() {
    const savedLogs = JSON.parse(localStorage.getItem('api_logs') || '[]');
    savedLogs.forEach(logEntry => {
        const div = document.createElement('div');
        div.className = `log-entry ${logEntry.type}`;
        div.innerHTML = `<span class="time">[${logEntry.time}]</span> ${logEntry.message}`;
        elements.logs.appendChild(div);
    });
}

// Работа с API - ИСПРАВЛЕННАЯ ВЕРСИЯ
async function apiRequest(method, endpoint, data = null, requiresAuth = false) {
    console.log(`API Request: ${method} ${endpoint}`, { requiresAuth, hasToken: !!currentToken });
    
    const headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'WebClient/1.0'
    };
    
    if (requiresAuth && currentToken) {
        headers['Authorization'] = `Bearer ${currentToken}`;
        console.log('Adding Authorization header:', headers['Authorization'].substring(0, 30) + '...');
    }
    
    const config = {
        method: method,
        headers: headers,
        mode: 'cors'
    };
    
    if (data && (method === 'POST' || method === 'PUT')) {
        config.body = JSON.stringify(data);
    }
    
    try {
        const url = `${API_BASE_URL}${endpoint}`;
        console.log('Fetching URL:', url);
        console.log('Config:', config);
        
        const response = await fetch(url, config);
        console.log('Response status:', response.status, response.statusText);
        
        let responseData;
        const contentType = response.headers.get('content-type');
        
        if (contentType && contentType.includes('application/json')) {
            responseData = await response.json();
        } else {
            responseData = await response.text();
        }
        
        const result = {
            ok: response.ok,
            status: response.status,
            statusText: response.statusText,
            data: responseData
        };
        
        if (!response.ok) {
            console.error('API Error:', result);
        } else {
            console.log('API Success:', result.data);
        }
        
        return result;
    } catch (error) {
        console.error('Network error:', error);
        return {
            ok: false,
            status: 0,
            statusText: error.message,
            data: null
        };
    }
}

// Авторизация - ИСПРАВЛЕННАЯ
async function login() {
    console.log('Login attempt...');
    const username = elements.username.value.trim();
    const password = elements.password.value.trim();
    
    if (!username || !password) {
        showError('Введите логин и пароль');
        return;
    }
    
    console.log('Credentials:', { username, password: '***' });
    
    const result = await apiRequest('POST', '/api/auth/login', {
        username,
        password
    });
    
    console.log('Login result:', result);
    
    if (result.ok && result.data) {
        // Пробуем получить токен из разных свойств
        let token = null;
        
        if (result.data.Token) token = result.data.Token;
        else if (result.data.token) token = result.data.token;
        else if (result.data.accessToken) token = result.data.accessToken;
        
        if (token) {
            console.log('Token received, length:', token.length);
            console.log('Token preview:', token.substring(0, 30) + '...');
            
            currentToken = token;
            localStorage.setItem('api_token', token);
            
            showSuccess(`Успешная авторизация: ${result.data.Username || username}`);
            updateUI();
            
            // Сразу проверяем токен
            setTimeout(() => checkTokenValidity(), 500);
        } else {
            console.error('No token in response:', result.data);
            showError('Токен не найден в ответе сервера');
        }
    } else {
        console.error('Login failed:', result);
        showError(`Ошибка авторизации: ${result.data?.message || result.statusText || 'Неизвестная ошибка'}`);
    }
}

// Проверка токена - ИСПРАВЛЕННАЯ
async function checkTokenValidity() {
    console.log('Checking token validity...');
    
    if (!currentToken) {
        console.log('No token to check');
        return;
    }
    
    const result = await apiRequest('GET', '/api/auth/validate', null, true);
    console.log('Validate result:', result);
    
    if (result.ok && result.data) {
        if (result.data.IsValid) {
            console.log('Token is valid');
            showSuccess('Токен действителен');
        } else {
            console.log('Token is invalid:', result.data.Message);
            showError(`Токен недействителен: ${result.data.Message}`);
            
            // Если токен невалиден, очищаем его
            if (result.data.Message && result.data.Message.includes('недействителен')) {
                currentToken = '';
                localStorage.removeItem('api_token');
                updateUI();
            }
        }
    } else {
        console.error('Validate request failed:', result);
        showError('Не удалось проверить токен');
    }
}

// Logout
async function logout() {
    console.log('Logout...');
    
    if (!currentToken) {
        console.log('No token to logout');
        return;
    }
    
    const result = await apiRequest('POST', '/api/auth/logout', null, true);
    console.log('Logout result:', result);
    
    if (result.ok) {
        showSuccess('Успешный выход из системы');
    }
    
    currentToken = '';
    localStorage.removeItem('api_token');
    updateUI();
}

// Получение данных
async function getUserInfo() {
    console.log('Getting user info...');
    const result = await apiRequest('GET', '/api/data/user-info', null, true);
    console.log('User info result:', result);
    
    if (result.ok) {
        elements.userData.textContent = JSON.stringify(result.data, null, 2);
        showSuccess('Данные пользователя получены');
    } else if (result.status === 401) {
        showError('Сессия истекла. Пожалуйста, войдите снова.');
        logout();
    } else {
        elements.userData.textContent = `Ошибка ${result.status}: ${JSON.stringify(result.data, null, 2)}`;
        showError(`Ошибка: ${result.status} ${result.statusText}`);
    }
}

async function getAdminData() {
    console.log('Getting admin data...');
    const result = await apiRequest('GET', '/api/data/admin-data', null, true);
    console.log('Admin data result:', result);
    
    if (result.ok) {
        elements.adminData.textContent = JSON.stringify(result.data, null, 2);
        showSuccess('Админ данные получены');
    } else if (result.status === 403) {
        showError('Доступ запрещен. У вас нет прав администратора.');
        elements.adminData.textContent = 'Доступ запрещен. Требуется роль Admin.';
    } else if (result.status === 401) {
        showError('Сессия истекла');
        logout();
    } else {
        elements.adminData.textContent = `Ошибка ${result.status}: ${JSON.stringify(result.data, null, 2)}`;
    }
}

async function getStats() {
    console.log('Getting stats...');
    const result = await apiRequest('GET', '/api/data/stats', null, true);
    console.log('Stats result:', result);
    
    if (result.ok) {
        elements.statsData.textContent = JSON.stringify(result.data, null, 2);
        showSuccess('Статистика получена');
    } else {
        elements.statsData.textContent = `Ошибка ${result.status}: ${JSON.stringify(result.data, null, 2)}`;
    }
}

// Публичные эндпоинты
async function getPublicInfo() {
    console.log('Getting public info...');
    const result = await apiRequest('GET', '/api/public/info');
    console.log('Public info result:', result);
    
    if (result.ok) {
        elements.publicData.textContent = JSON.stringify(result.data, null, 2);
        showSuccess('Публичная информация получена');
    } else {
        elements.publicData.textContent = `Ошибка ${result.status}: ${JSON.stringify(result.data, null, 2)}`;
    }
}

async function getHealth() {
    console.log('Getting health check...');
    const result = await apiRequest('GET', '/api/public/health');
    console.log('Health result:', result);
    
    if (result.ok) {
        elements.publicData.textContent = JSON.stringify(result.data, null, 2);
        showSuccess('Проверка здоровья выполнена');
    } else {
        elements.publicData.textContent = `Ошибка ${result.status}: ${JSON.stringify(result.data, null, 2)}`;
    }
}

// Инициализация
function init() {
    console.log('Initializing app...');
    
    // Загрузка логов
    loadLogs();
    
    // Обновление UI
    updateUI();
    
    // События
    elements.btnLogin.addEventListener('click', login);
    elements.btnLogout.addEventListener('click', logout);
    
    // Тестовые пользователи
    document.querySelectorAll('.user-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            elements.username.value = btn.dataset.user;
            elements.password.value = btn.dataset.pass;
            log(`Выбран пользователь: ${btn.dataset.user}`);
        });
    });
    
    // Получение данных
    elements.btnGetUserInfo.addEventListener('click', getUserInfo);
    elements.btnGetAdminData.addEventListener('click', getAdminData);
    elements.btnGetStats.addEventListener('click', getStats);
    elements.btnGetPublicInfo.addEventListener('click', getPublicInfo);
    elements.btnGetHealth.addEventListener('click', getHealth);
    
    // Логи
    elements.btnClearLogs.addEventListener('click', () => {
        elements.logs.innerHTML = '';
        localStorage.removeItem('api_logs');
        log('Логи очищены');
    });
    
    // Табы
    elements.tabButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            elements.tabButtons.forEach(b => b.classList.remove('active'));
            elements.tabPanes.forEach(p => p.classList.remove('active'));
            btn.classList.add('active');
            document.getElementById(`tab-${btn.dataset.tab}`).classList.add('active');
        });
    });
    
    // Проверка публичного API
    setTimeout(() => {
        apiRequest('GET', '/api/public/info').then(result => {
            if (result.ok) {
                log(`API доступен: ${result.data?.Application || 'ASP.NET Web API'}`, 'success');
            } else {
                log(`API недоступен: ${result.status}`, 'error');
            }
        });
    }, 1000);
    
    // Проверяем сохраненный токен
    if (currentToken) {
        console.log('Found saved token, checking validity...');
        setTimeout(() => checkTokenValidity(), 1500);
    }
}

// Запуск
document.addEventListener('DOMContentLoaded', init);