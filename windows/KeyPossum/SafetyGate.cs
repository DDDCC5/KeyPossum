using System.Diagnostics;
using System.IO.MemoryMappedFiles;
using System.Runtime.InteropServices;

namespace KeyPossum;

// A child of this process owns the last-resort deadline. It never installs hooks.
internal sealed class SafetyGate : IDisposable
{
    private readonly MemoryMappedFile memory;
    private readonly MemoryMappedViewAccessor view;
    private readonly EventWaitHandle stop, ready;
    private readonly Process child;
    internal static long Now => Stopwatch.GetTimestamp();
    internal static long Seconds(double seconds) => (long)(seconds * Stopwatch.Frequency);
    internal SafetyGate()
    {
        string name="Local\\KeyPossum-"+Guid.NewGuid().ToString("N");
        memory=MemoryMappedFile.CreateNew(name,16);
        view=memory.CreateViewAccessor();
        stop=new EventWaitHandle(false,EventResetMode.ManualReset,name+"-stop");
        ready=new EventWaitHandle(false,EventResetMode.ManualReset,name+"-ready");
        SetDeadline(Now+Seconds(60)); Heartbeat();
        var me=Process.GetCurrentProcess();
        var info=new ProcessStartInfo(Environment.ProcessPath!){UseShellExecute=false,CreateNoWindow=true};
        foreach(string arg in new[]{"--supervise",me.Id.ToString(),me.StartTime.ToUniversalTime().Ticks.ToString(),name}) info.ArgumentList.Add(arg);
        try {
            child=Process.Start(info) ?? throw new InvalidOperationException("supervisor");
            if(!ready.WaitOne(5000) || child.HasExited) throw new InvalidOperationException("supervisor");
        } catch { stop.Set(); view.Dispose(); memory.Dispose(); stop.Dispose(); ready.Dispose(); throw; }
    }
    internal void SetDeadline(long ticks) => view.Write(0,ticks);
    internal void Heartbeat() => view.Write(8,Now);
    internal bool IsAlive => !child.HasExited;
    public void Dispose()
    {
        stop.Set();
        view.Dispose(); memory.Dispose(); stop.Dispose(); ready.Dispose(); child.Dispose();
    }
    [StructLayout(LayoutKind.Sequential)] private struct BasicProcess { public nint Reserved1, Peb, Reserved2, Reserved3, Pid, ParentPid; }
    [DllImport("ntdll.dll")] private static extern int NtQueryInformationProcess(nint process, int kind, out BasicProcess info, int size, out int returned);
    internal static int Supervise(string[] args)
    {
        try {
            if(args.Length!=4 || !int.TryParse(args[1],out int pid) || !long.TryParse(args[2],out long started)) return 2;
            using var self=Process.GetCurrentProcess();
            if(NtQueryInformationProcess(self.Handle,0,out var basic,Marshal.SizeOf<BasicProcess>(),out _)!=0 || basic.ParentPid!=(nint)pid) return 2;
            using var parent=Process.GetProcessById(pid);
            if(parent.StartTime.ToUniversalTime().Ticks!=started || !string.Equals(parent.MainModule?.FileName,Environment.ProcessPath,StringComparison.OrdinalIgnoreCase)) return 2;
            using var memory=MemoryMappedFile.OpenExisting(args[3],MemoryMappedFileRights.Read);
            using var view=memory.CreateViewAccessor(0,16,MemoryMappedFileAccess.Read);
            using var stop=EventWaitHandle.OpenExisting(args[3]+"-stop");
            using var ready=EventWaitHandle.OpenExisting(args[3]+"-ready");
            ready.Set();
            while(!stop.WaitOne(25)) {
                if(parent.HasExited) return 0;
                long now=Now;
                if(now>=view.ReadInt64(0) || now-view.ReadInt64(8)>Seconds(4)) {
                    // Retained process handle and OS parent identity prevent PID reuse/other-process targeting.
                    if(!parent.HasExited) parent.Kill(entireProcessTree:false);
                    return 0;
                }
            }
            return 0;
        } catch { return 2; }
    }
}
