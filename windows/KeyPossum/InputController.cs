using System.Diagnostics;
using System.Runtime.InteropServices;
using KeyPossum.Core;

namespace KeyPossum;

internal sealed class InputController : IDisposable
{
    private readonly string code, fingerprint;
    private readonly double duration;
    private readonly Native.HookProc keyboard, mouse;
    private readonly Thread thread;
    private readonly object hookLifecycle=new();
    private Session? session;
    private SafetyGate? safety;
    private nint keyboardHook, mouseHook;
    private uint threadId;
    private int stopped, started, cleaningStarted;
    private long uiBeat=SafetyGate.Now, workerBeat=SafetyGate.Now, deadline;
    private readonly SessionFeed feed=new();
    internal SessionView Snapshot => feed.Read;
    internal InputController(string code, Capability capability, bool trial)
    {
        this.code=code; fingerprint=capability.Fingerprint; duration=trial?15:180;
        keyboard=Keyboard; mouse=Mouse;
        thread=new Thread(Run){IsBackground=true,Name="KeyPossum input"};
    }
    internal void Start() { if(Interlocked.Exchange(ref started,1)==0) thread.Start(); }
    internal void Heartbeat()
    {
        Interlocked.Exchange(ref uiBeat,SafetyGate.Now);
        try { safety?.Heartbeat(); } catch(ObjectDisposedException) { }
    }
    private static double Time => Stopwatch.GetTimestamp()/(double)Stopwatch.Frequency;
    private static int ScanId(uint scan, bool extended) => checked((int)(scan&0xff)) | (extended?0x100:0);
    private void Run()
    {
        nuint timer=0;
        try {
            if(Capabilities.Inspect().Fingerprint!=fingerprint || !Capabilities.IsDefaultDesktop()) throw new InvalidOperationException("capability");
            // A released initial state also prevents a mouse button being held across the lock boundary.
            for(int vk=1;vk<256;vk++) if((Native.GetAsyncKeyState(vk)&0x8000)!=0) throw new InvalidOperationException("release-initial");
            int[] keys=code.Select(c=>Native.MapVirtualKeyW(c,4)).Select(scan=>ScanId(scan,(scan&0xff00)!=0)).ToArray();
            session=new Session(keys,Time,duration);
            safety=new SafetyGate();
            deadline=SafetyGate.Now+SafetyGate.Seconds(60);
            safety.SetDeadline(deadline);
            threadId=Native.GetCurrentThreadId();
            Native.PeekMessageW(out _,0,0,0,0);
            lock(hookLifecycle) {
                if(Volatile.Read(ref stopped)!=0) return;
                keyboardHook=Native.SetWindowsHookExW(13,keyboard,Native.GetModuleHandleW(null),0);
                mouseHook=Native.SetWindowsHookExW(14,mouse,Native.GetModuleHandleW(null),0);
            }
            if(keyboardHook==0 || mouseHook==0) throw new InvalidOperationException("hooks");
            // The supervisor handshake can take seconds: sample again after interception exists.
            for(int vk=1;vk<256;vk++) if((Native.GetAsyncKeyState(vk)&0x8000)!=0) throw new InvalidOperationException("release-initial");
            timer=Native.SetTimer(0,0,20,0);
            if(timer==0) throw new InvalidOperationException("timer");
            var watcher=new Thread(Watch){IsBackground=true,Name="KeyPossum safety"}; watcher.Start();
            while(Volatile.Read(ref stopped)==0) {
                int result=Native.GetMessageW(out var message,0,0,0);
                if(result<=0) { if(result<0) Stop("backend"); break; }
                Interlocked.Exchange(ref workerBeat,SafetyGate.Now);
                if(message.Id==0x113) {
                    if(session.Phase==Phase.Preparing && new[]{1,2,4,5,6}.Any(vk=>(Native.GetAsyncKeyState(vk)&0x8000)!=0)) session.Stop("preparation-cancelled");
                    session.Tick(Time); Publish();
                }
                else { Native.TranslateMessage(ref message); Native.DispatchMessageW(ref message); }
            }
        } catch(Exception e) { Stop(e is InvalidOperationException ? e.Message : "backend"); }
        finally {
            if(timer!=0) Native.KillTimer(0,timer);
            Stop(Snapshot.Reason.Length>0?Snapshot.Reason:"backend");
            lock(hookLifecycle){safety?.Dispose(); safety=null;}
        }
    }
    private void Watch()
    {
        long nextCapabilityCheck=0;
        while(Volatile.Read(ref stopped)==0) {
            long now=SafetyGate.Now;
            if(now-Interlocked.Read(ref uiBeat)>SafetyGate.Seconds(3)) { Stop("ui-timeout"); return; }
            if(now-Interlocked.Read(ref workerBeat)>SafetyGate.Seconds(1)) { Stop("backend"); return; }
            // Clean up before the helper's hard ceiling so healthy trial sessions retain their UI.
            if(now>=Interlocked.Read(ref deadline)-SafetyGate.Seconds(0.25)) { Stop(cleaningStarted!=0?"timeout":"verification-timeout"); return; }
            try {
                if(safety is null || !safety.IsAlive) { Stop("supervisor"); return; }
                if(!Capabilities.IsDefaultDesktop()) { Stop("desktop"); return; }
                if(now>=nextCapabilityCheck) {
                    if(Capabilities.Inspect().Fingerprint!=fingerprint) { Stop("devices"); return; }
                    nextCapabilityCheck=now+SafetyGate.Seconds(1);
                }
            } catch { Stop("capability"); return; }
            Thread.Sleep(25);
        }
    }
    private void Publish()
    {
        lock(hookLifecycle) {
        if(session is null || Volatile.Read(ref stopped)!=0) return;
        if(session.CleaningStarted is double began && Interlocked.CompareExchange(ref cleaningStarted,1,0)==0) {
            long bound=(long)((began+duration)*Stopwatch.Frequency);
            safety!.SetDeadline(bound); Interlocked.Exchange(ref deadline,bound);
        }
        if(session.Phase==Phase.Ended){Stop(session.Reason);return;}
        feed.Publish(new(session.Phase,session.Remaining,session.Progress,session.Reason,cleaningStarted!=0));
        }
    }
    private nint Keyboard(int n, nuint message, nint data)
    {
        if(n<0 || Volatile.Read(ref stopped)!=0 || session is null) return Native.CallNextHookEx(0,n,message,data);
        bool suppress=session.SuppressKeyboard;
        try {
            var e=Marshal.PtrToStructure<Native.KeyData>(data);
            bool down=message is 0x100 or 0x104;
            bool injected=(e.Flags&0x12)!=0;
            session.Key(ScanId(e.Scan,(e.Flags&1)!=0),down,injected,Time);
            // Verification is keyboard-only interception; mouse remains available to cancel.
            suppress |= session.SuppressKeyboard;
            Publish();
            return suppress ? 1 : Native.CallNextHookEx(0,n,message,data);
        } catch { Stop("backend"); return Native.CallNextHookEx(0,n,message,data); }
    }
    private nint Mouse(int n, nuint message, nint data)
    {
        if(n<0 || Volatile.Read(ref stopped)!=0 || session is null) return Native.CallNextHookEx(0,n,message,data);
        bool suppress=session.Suppressing;
        try { session.Activity(Time); Publish(); return suppress?1:Native.CallNextHookEx(0,n,message,data); }
        catch { Stop("backend"); return Native.CallNextHookEx(0,n,message,data); }
    }
    internal void Stop(string reason)
    {
        if(Interlocked.Exchange(ref stopped,1)!=0) return;
        bool okay=true;
        lock(hookLifecycle) {
            nint k=Interlocked.Exchange(ref keyboardHook,0), m=Interlocked.Exchange(ref mouseHook,0);
            if(k!=0) okay &= Native.UnhookWindowsHookEx(k);
            if(m!=0) okay &= Native.UnhookWindowsHookEx(m);
        }
        feed.Publish(new(Phase.Ended,0,0,reason,Volatile.Read(ref cleaningStarted)!=0));
        if(threadId!=0) Native.PostThreadMessageW(threadId,0x12,0,0);
        // If removal cannot be confirmed, process termination removes its hooks.
        if(!okay) Environment.Exit(3);
    }
    public void Dispose() => Stop("cancelled");
}
