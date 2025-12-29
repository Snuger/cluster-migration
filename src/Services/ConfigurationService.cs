using System.IO;
using System.Text.Json;
using System.Text;
using Microsoft.Extensions.Configuration;

namespace Cyan_Service_Migration.Services
{
    public class ConfigurationService
    {
        private readonly IConfiguration _configuration;
        private readonly string _appSettingsPath;

        public ConfigurationService(IConfiguration configuration, IWebHostEnvironment env)
        {
            _configuration = configuration;
            _appSettingsPath = Path.Combine(env.ContentRootPath, "appsettings.json");
        }

        public T GetSection<T>(string sectionName)
        {
            return _configuration.GetSection(sectionName).Get<T>();
        }

        public void UpdateSection<T>(string sectionName, T value)
        {
            var json = File.ReadAllText(_appSettingsPath);
            var jsonDocument = JsonDocument.Parse(json);
            var root = jsonDocument.RootElement.Clone();

            using (var stream = new MemoryStream())
            using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = true }))
            {
                writer.WriteStartObject();

                foreach (var property in root.EnumerateObject())
                {
                    if (property.Name == sectionName)
                    {
                        JsonSerializer.Serialize(writer, value);
                    }
                    else
                    {
                        property.WriteTo(writer);
                    }
                }

                writer.WriteEndObject();
                writer.Flush();

                var newJson = Encoding.UTF8.GetString(stream.ToArray());
                File.WriteAllText(_appSettingsPath, newJson);
            }
        }
    }
}