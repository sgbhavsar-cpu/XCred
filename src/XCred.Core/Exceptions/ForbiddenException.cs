namespace XCred.Core.Exceptions;

public class ForbiddenException(string message = "Access denied.") : Exception(message);
