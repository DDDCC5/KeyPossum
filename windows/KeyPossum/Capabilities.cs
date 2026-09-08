using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

namespace KeyPossum;

internal record Capability(string Fingerprint);
internal static class Capabilities
{
    // Capability queries are performed before hooks and on a watchdog, never in callbacks.
    internal static Capability Inspect()
    {
        if (!OperatingSystem.IsWindowsVersionAtLeast(10,0,22000) || RuntimeInformation.ProcessArchitecture != Architecture.X64)
            throw new InvalidOperationException("platform");
        if (Native.GetSystemMetrics(0x1000) != 0) throw new InvalidOperationException("remote");
        int digitizer = Native.GetSystemMetrics(94);
        if ((digitizer & 3) != 0 || Native.GetSystemMetrics(95) > 0) throw new InvalidOperationException("touch");
        // Pen digitizers also have paths beyond mouse hooks: conservatively block them.
        if ((digitizer & 12) != 0) throw new InvalidOperationException("touch");
        if (digitizer != 0 && (digitizer & 0x80) == 0) throw new InvalidOperationException("capability");
        uint count=0, size=(uint)Marshal.SizeOf<Native.RawDevice>();
        if (Native.GetRawInputDeviceList(null,ref count,size)==uint.MaxValue || count==0 || count>1024) throw new InvalidOperationException("capability");
        var list=new Native.RawDevice[count];
        uint found=Native.GetRawInputDeviceList(list,ref count,size);
        if(found==uint.MaxValue || found>list.Length) throw new InvalidOperationException("capability");
        var names=new List<string>(); bool keyboard=false;
        foreach(var d in list.Take((int)found)) {
            uint infoSize=32; var info=new Native.DeviceInfo{Size=32};
            if(Native.GetRawInputDeviceInfoW(d.Handle,0x2000000b,ref info,ref infoSize)==uint.MaxValue) throw new InvalidOperationException("capability");
            if(d.Type==2 && info.UsagePage==13 && info.Usage!=5) throw new InvalidOperationException("touch");
            keyboard |= d.Type==1;
            uint length=0;
            if(Native.GetRawInputDeviceInfoW(d.Handle,0x20000007,(StringBuilder?)null,ref length)==uint.MaxValue || length==0 || length>32768) throw new InvalidOperationException("capability");
            var name=new StringBuilder((int)length+1);
            if(Native.GetRawInputDeviceInfoW(d.Handle,0x20000007,name,ref length)==uint.MaxValue) throw new InvalidOperationException("capability");
            names.Add($"{d.Type}:{name}");
        }
        if(!keyboard) throw new InvalidOperationException("capability");
        names.Sort(StringComparer.Ordinal);
        string identity=$"{Environment.OSVersion.Version}|0.1.0-alpha.1|{digitizer}|{string.Join("\n",names)}";
        return new(Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(identity))));
    }
    internal static bool IsDefaultDesktop()
    {
        nint d=Native.OpenInputDesktop(0,false,1);
        if(d==0) return false;
        try { var name=new StringBuilder(256); return Native.GetUserObjectInformationW(d,2,name,512,out _) && name.ToString().Equals("Default",StringComparison.OrdinalIgnoreCase); }
        finally { Native.CloseDesktop(d); }
    }
}
