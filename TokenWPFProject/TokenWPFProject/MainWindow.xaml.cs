using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Windows;

namespace TokenWPFProject
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        private HttpClient _httpClient;
        private string _token = string.Empty;
        private string _username = string.Empty;
        private const string BaseUrl = "http://localhost:5261";

        public MainWindow()
        {
            InitializeComponent();
            InitializeHttpClient();
            Log("Клиент инициализирован. Ожидание авторизации...");
        }

        private void InitializeHttpClient()
        {
            _httpClient = new HttpClient();
            _httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("WPF-App/1.0");
        }

        private async void BtnLogin_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var loginData = new
                {
                    username = txtUsername.Text,
                    password = txtPassword.Password
                };

                var json = JsonSerializer.Serialize(loginData);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                Log($"Отправка запроса на логин: {txtUsername.Text}");
                var response = await _httpClient.PostAsync($"{BaseUrl}/api/auth/login", content);

                if (response.IsSuccessStatusCode)
                {
                    var responseJson = await response.Content.ReadAsStringAsync();
                    Log($"Ответ сервера: {responseJson}");

                    using var doc = JsonDocument.Parse(responseJson);
                    var root = doc.RootElement;

                    // Получаем токен (проверяем разные возможные имена свойств)
                    if (root.TryGetProperty("Token", out var tokenElement) ||
                        root.TryGetProperty("token", out tokenElement) ||
                        root.TryGetProperty("accessToken", out tokenElement))
                    {
                        _token = tokenElement.GetString() ?? string.Empty;
                    }

                    // Получаем имя пользователя
                    if (root.TryGetProperty("Username", out var userElement) ||
                        root.TryGetProperty("username", out userElement))
                    {
                        _username = userElement.GetString() ?? string.Empty;
                    }

                    // Получаем роль (если есть)
                    string role = "User";
                    if (root.TryGetProperty("Role", out var roleElement) ||
                        root.TryGetProperty("role", out roleElement))
                    {
                        role = roleElement.GetString() ?? "User";
                    }

                    if (!string.IsNullOrEmpty(_token))
                    {
                        lblAuthStatus.Text = $"Авторизован: {_username} ({role})";
                        btnLogin.IsEnabled = false;
                        btnLogout.IsEnabled = true;
                        btnGetUserInfo.IsEnabled = true;
                        btnGetAdminData.IsEnabled = true;
                        btnGetStats.IsEnabled = true;

                        Log($"Успешная авторизация. Токен получен. Длина: {_token.Length} символов");

                        // Проверим валидность токена
                        await CheckTokenValidity();
                    }
                    else
                    {
                        Log("ОШИБКА: Токен не найден в ответе сервера");
                        MessageBox.Show("Токен не получен от сервера");
                    }
                }
                else
                {
                    var error = await response.Content.ReadAsStringAsync();
                    Log($"Ошибка авторизации: {response.StatusCode} - {error}");
                    MessageBox.Show($"Ошибка авторизации: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Log($"Исключение при авторизации: {ex.Message}");
                MessageBox.Show($"Ошибка: {ex.Message}");
            }
        }

        private async Task CheckTokenValidity()
        {
            try
            {
                _httpClient.DefaultRequestHeaders.Authorization =
                    new AuthenticationHeaderValue("Bearer", _token);

                var response = await _httpClient.GetAsync($"{BaseUrl}/api/auth/validate");
                if (response.IsSuccessStatusCode)
                {
                    var json = await response.Content.ReadAsStringAsync();
                    using var doc = JsonDocument.Parse(json);
                    var isValid = doc.RootElement.GetProperty("IsValid").GetBoolean();

                    Log($"Проверка токена: {(isValid ? "валиден" : "невалиден")}");
                }
            }
            catch (Exception ex)
            {
                Log($"Ошибка проверки токена: {ex.Message}");
            }
        }

        private async void BtnLogout_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                if (string.IsNullOrEmpty(_token))
                {
                    MessageBox.Show("Нет активной сессии");
                    return;
                }

                _httpClient.DefaultRequestHeaders.Authorization =
                    new AuthenticationHeaderValue("Bearer", _token);

                Log("Отправка запроса на логаут");
                var response = await _httpClient.PostAsync($"{BaseUrl}/api/auth/logout", null);

                if (response.IsSuccessStatusCode)
                {
                    _token = string.Empty;
                    _username = string.Empty;
                    _httpClient.DefaultRequestHeaders.Authorization = null;

                    lblAuthStatus.Text = "Не авторизован";
                    btnLogin.IsEnabled = true;
                    btnLogout.IsEnabled = false;
                    btnGetUserInfo.IsEnabled = false;
                    btnGetAdminData.IsEnabled = false;
                    btnGetStats.IsEnabled = false;

                    txtUserInfo.Clear();
                    txtAdminData.Clear();
                    txtStats.Clear();

                    Log("Успешный логаут");
                }
                else
                {
                    Log($"Ошибка логаута: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Log($"Исключение при логауте: {ex.Message}");
            }
        }

        private async void BtnGetUserInfo_Click(object sender, RoutedEventArgs e)
        {
            await MakeAuthenticatedRequest("/api/data/user-info", txtUserInfo);
        }

        private async void BtnGetAdminData_Click(object sender, RoutedEventArgs e)
        {
            await MakeAuthenticatedRequest("/api/data/admin-data", txtAdminData);
        }

        private async void BtnGetStats_Click(object sender, RoutedEventArgs e)
        {
            await MakeAuthenticatedRequest("/api/data/stats", txtStats);
        }

        private async Task MakeAuthenticatedRequest(string endpoint, System.Windows.Controls.TextBox outputBox)
        {
            try
            {
                if (string.IsNullOrEmpty(_token))
                {
                    MessageBox.Show("Сначала авторизуйтесь");
                    return;
                }

                _httpClient.DefaultRequestHeaders.Authorization =
                    new AuthenticationHeaderValue("Bearer", _token);

                Log($"Запрос к {endpoint}");
                var response = await _httpClient.GetAsync($"{BaseUrl}{endpoint}");

                if (response.IsSuccessStatusCode)
                {
                    var json = await response.Content.ReadAsStringAsync();
                    Log($"Успешный ответ от {endpoint}");

                    // Пытаемся красиво отформатировать JSON
                    try
                    {
                        var doc = JsonDocument.Parse(json);
                        var formattedJson = JsonSerializer.Serialize(
                            doc.RootElement,
                            new JsonSerializerOptions { WriteIndented = true });
                        outputBox.Text = formattedJson;
                    }
                    catch
                    {
                        outputBox.Text = json;
                    }
                }
                else
                {
                    var error = await response.Content.ReadAsStringAsync();
                    outputBox.Text = $"Ошибка {response.StatusCode}:\n{error}";
                    Log($"Ошибка от {endpoint}: {response.StatusCode}");

                    // Если 401 - токен невалиден
                    if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized)
                    {
                        _token = string.Empty;
                        lblAuthStatus.Text = "Сессия истекла";
                        btnLogin.IsEnabled = true;
                        btnLogout.IsEnabled = false;
                        btnGetUserInfo.IsEnabled = false;
                        btnGetAdminData.IsEnabled = false;
                        btnGetStats.IsEnabled = false;
                    }
                }
            }
            catch (Exception ex)
            {
                outputBox.Text = $"Исключение: {ex.Message}";
                Log($"Исключение при запросе к {endpoint}: {ex.Message}");
            }
        }

        private void Log(string message)
        {
            Dispatcher.Invoke(() =>
            {
                txtLog.AppendText($"[{DateTime.Now:HH:mm:ss}] {message}\n");
                txtLog.ScrollToEnd();
            });
        }
    }
}