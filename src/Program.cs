using Cyan_Service_Migration.Data;
using Cyan_Service_Migration.Services;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<MigrationLockService>();

// Add services to the container.
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();
builder.Services.AddSingleton<WeatherForecastService>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddHostedService<ScheduledTaskService>();
builder.Services.Configure<ScheduledTaskSettings>(builder.Configuration.GetSection("ScheduledTask"));

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseStaticFiles();

app.UseRouting();

app.MapGet("/", context =>
{
    context.Response.Redirect("/migration");
    return Task.CompletedTask;
});

app.MapBlazorHub();
app.MapFallbackToPage("/_Host");

app.Run();