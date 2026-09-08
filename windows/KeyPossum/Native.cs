using System.Runtime.InteropServices;
using System.Text;

namespace KeyPossum;

internal static class Native
{
    internal delegate nint HookProc(int code, nuint message, nint data);
    [StructLayout(LayoutKind.Sequential)] internal struct KeyData { public uint Vk, Scan, Flags, Time; public nuint Extra; }
    [StructLayout(LayoutKind.Sequential)] internal struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] internal struct Message { public nint Window; public uint Id; public nuint WParam; public nint LParam; public uint Time; public Point Point; public uint Private; }
    [StructLayout(LayoutKind.Sequential)] internal struct RawDevice { public nint Handle; public uint Type; }
    [StructLayout(LayoutKind.Explicit, Size=32)] internal struct DeviceInfo {
        [FieldOffset(0)] public uint Size; [FieldOffset(4)] public uint Type;
        [FieldOffset(8)] public uint Vendor; [FieldOffset(12)] public uint Product; [FieldOffset(16)] public uint Version;
        [FieldOffset(20)] public ushort UsagePage; [FieldOffset(22)] public ushort Usage;
    }
    [DllImport("user32.dll", SetLastError=true)] internal static extern nint SetWindowsHookExW(int id, HookProc proc, nint module, uint thread);
    [DllImport("user32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool UnhookWindowsHookEx(nint hook);
    [DllImport("user32.dll")] internal static extern nint CallNextHookEx(nint hook, int code, nuint message, nint data);
    [DllImport("user32.dll")] internal static extern int GetMessageW(out Message message, nint window, uint min, uint max);
    [DllImport("user32.dll")] internal static extern bool PeekMessageW(out Message message, nint window, uint min, uint max, uint remove);
    [DllImport("user32.dll")] internal static extern bool TranslateMessage(ref Message message);
    [DllImport("user32.dll")] internal static extern nint DispatchMessageW(ref Message message);
    [DllImport("user32.dll")] internal static extern bool PostThreadMessageW(uint thread, uint message, nuint wParam, nint lParam);
    [DllImport("user32.dll")] internal static extern nuint SetTimer(nint window, nuint id, uint ms, nint callback);
    [DllImport("user32.dll")] internal static extern bool KillTimer(nint window, nuint id);
    [DllImport("kernel32.dll")] internal static extern uint GetCurrentThreadId();
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] internal static extern nint GetModuleHandleW(string? name);
    [DllImport("user32.dll")] internal static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] internal static extern uint MapVirtualKeyW(uint code, uint type);
    [DllImport("user32.dll")] internal static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll", SetLastError=true)] internal static extern uint GetRawInputDeviceList([Out] RawDevice[]? devices, ref uint count, uint size);
    [DllImport("user32.dll", SetLastError=true)] internal static extern uint GetRawInputDeviceInfoW(nint device, uint command, ref DeviceInfo info, ref uint size);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] internal static extern uint GetRawInputDeviceInfoW(nint device, uint command, StringBuilder? text, ref uint size);
    [DllImport("Wtsapi32.dll")] internal static extern bool WTSRegisterSessionNotification(nint window, uint flags);
    [DllImport("Wtsapi32.dll")] internal static extern bool WTSUnRegisterSessionNotification(nint window);
    [DllImport("user32.dll", SetLastError=true)] internal static extern nint OpenInputDesktop(uint flags, bool inherit, uint access);
    [DllImport("user32.dll")] internal static extern bool CloseDesktop(nint desktop);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] internal static extern bool GetUserObjectInformationW(nint handle, int index, StringBuilder text, uint length, out uint needed);
}
