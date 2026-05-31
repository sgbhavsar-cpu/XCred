using XCred.Core.Entities;

namespace XCred.Core.Interfaces;

public interface ITokenService
{
    string GenerateAccessToken(User user);
    (string token, string hash) GenerateRefreshToken();
    Guid? GetUserIdFromToken(string token);
}
