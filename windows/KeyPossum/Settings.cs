using System.IO;
using System.Text.Json;
using KeyPossum.Core;

namespace KeyPossum;

internal sealed class Settings
{
    public string? CustomCode {get;set;}
    public string? QualifiedFingerprint {get;set;}
    public bool SessionActive {get;set;}
    private static string FileName => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"KeyPossum","settings.json");
    internal static Settings Load()
    {
        try {
            if(!File.Exists(FileName) || new FileInfo(FileName).Length>8192) return new();
            var value=JsonSerializer.Deserialize<Settings>(File.ReadAllText(FileName)) ?? new();
            if(!Combination.IsValid(value.CustomCode)) value.CustomCode=null;
            if(value.QualifiedFingerprint is not {Length:64} || !value.QualifiedFingerprint.All(Uri.IsHexDigit)) value.QualifiedFingerprint=null;
            if(value.SessionActive){value.QualifiedFingerprint=null;value.SessionActive=false;}
            return value;
        } catch { return new(); }
    }
    internal void Save()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(FileName)!);
        string temporary=FileName+".tmp";
        File.WriteAllText(temporary,JsonSerializer.Serialize(this));
        File.Move(temporary,FileName,true);
    }
}
