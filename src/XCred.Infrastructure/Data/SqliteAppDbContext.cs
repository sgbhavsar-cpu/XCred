using Microsoft.EntityFrameworkCore;

namespace XCred.Infrastructure.Data;

/// Exists purely so EF Core's migration scoping can tell the two providers' migrations
/// apart (each migration's Designer.cs carries a [DbContext(typeof(...))] attribute tying
/// it to a specific concrete context type) — no members beyond the constructor. Registered
/// in place of AppDbContext when Database:Provider is "Sqlite"
/// (see ServiceExtensions.AddDatabase); every repository/controller keeps injecting plain
/// AppDbContext regardless of which one is actually running underneath.
public class SqliteAppDbContext(DbContextOptions<SqliteAppDbContext> options) : AppDbContext(options);
