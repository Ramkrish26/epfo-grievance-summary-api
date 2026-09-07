using Epfo.Grievance.Application;
using Epfo.Grievance.Domain;
using Microsoft.EntityFrameworkCore;

namespace Epfo.Grievance.Infrastructure;

public sealed class EpfoDbContext(DbContextOptions<EpfoDbContext> options) : DbContext(options)
{
    public DbSet<Office> Offices => Set<Office>(); public DbSet<Role> Roles => Set<Role>(); public DbSet<User> Users => Set<User>(); public DbSet<UserRole> UserRoles => Set<UserRole>(); public DbSet<CaseType> CaseTypes => Set<CaseType>(); public DbSet<CaseStatus> CaseStatuses => Set<CaseStatus>(); public DbSet<ServiceArea> ServiceAreas => Set<ServiceArea>(); public DbSet<GrievanceCase> Cases => Set<GrievanceCase>(); public DbSet<CaseAttribute> CaseAttributes => Set<CaseAttribute>(); public DbSet<JointDeclarationDetail> JointDeclarationDetails => Set<JointDeclarationDetail>(); public DbSet<CaseStatusHistory> CaseStatusHistory => Set<CaseStatusHistory>();
    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<Office>().ToTable("Offices").HasKey(x => x.OfficeId); b.Entity<Role>().ToTable("Roles").HasKey(x => x.RoleId); b.Entity<User>().ToTable("Users").HasKey(x => x.UserId); b.Entity<UserRole>().ToTable("UserRoles").HasKey(x => new { x.UserId, x.RoleId }); b.Entity<UserRole>().HasOne(x => x.User).WithMany(x => x.UserRoles).HasForeignKey(x => x.UserId); b.Entity<UserRole>().HasOne(x => x.Role).WithMany().HasForeignKey(x => x.RoleId);
        b.Entity<CaseType>().ToTable("CaseTypes").HasKey(x => x.CaseTypeId); b.Entity<CaseStatus>().ToTable("CaseStatuses").HasKey(x => x.CaseStatusId); b.Entity<ServiceArea>().ToTable("ServiceAreas").HasKey(x => x.ServiceAreaId);
        b.Entity<GrievanceCase>().ToTable("Cases").HasKey(x => x.CaseId); b.Entity<GrievanceCase>().HasOne(x => x.CaseType).WithMany().HasForeignKey(x => x.CaseTypeId); b.Entity<GrievanceCase>().HasOne(x => x.CaseStatus).WithMany().HasForeignKey(x => x.CaseStatusId); b.Entity<GrievanceCase>().HasMany(x => x.Attributes).WithOne(x => x.Case).HasForeignKey(x => x.CaseId);
        b.Entity<JointDeclarationDetail>().ToTable("JointDeclarationDetails").HasKey(x => x.CaseId); b.Entity<JointDeclarationDetail>().HasOne(x => x.Case).WithOne(x => x.JointDeclarationDetail).HasForeignKey<JointDeclarationDetail>(x => x.CaseId); b.Entity<CaseAttribute>().ToTable("CaseAttributes").HasKey(x => x.CaseAttributeId); b.Entity<CaseAttribute>().HasIndex(x => new { x.CaseId, x.AttributeName }).IsUnique(); b.Entity<CaseStatusHistory>().ToTable("CaseStatusHistory").HasKey(x => x.CaseStatusHistoryId);
    }
}

