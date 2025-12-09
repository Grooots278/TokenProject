using TokenASPProject.Models;

namespace TokenASPProject.Services
{
    public interface IUserService
    {
        User? Authenticate(string username, string password);
    }

    public class UserService : IUserService
    {
        private readonly List<User> _users = new()
        {
            new User { Username = "user1", Password = "password1", Role = "User" },
            new User { Username = "user2", Password = "password2", Role = "User" },
            new User { Username = "admin", Password = "admin123", Role = "Admin" }
        };

        public User? Authenticate(string username, string password) => _users.FirstOrDefault(x =>
                x.Username == username && x.Password == password);
    }
}
