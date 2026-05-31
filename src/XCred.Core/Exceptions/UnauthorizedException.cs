namespace XCred.Core.Exceptions;

public class UnauthorizedException(string message = "Unauthorized.") : Exception(message);
