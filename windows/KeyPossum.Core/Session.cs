using System.Security.Cryptography;

namespace KeyPossum.Core;

public static class Combination
{
    public const string Alphabet="ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    public static bool IsValid(string? code) => code is {Length:4} && code.All(Alphabet.Contains) && code.Distinct().Count()==4;
    public static string Random()
    {
        var pool=Alphabet.ToCharArray();
        for(int i=0;i<4;i++) { int j=RandomNumberGenerator.GetInt32(i,pool.Length); (pool[i],pool[j])=(pool[j],pool[i]); }
        return new string(pool,0,4);
    }
}

public enum Phase { Verifying, Release, Preparing, Cleaning, Draining, Ended }

/// <summary>Pure monotonic state; key IDs are physical scan codes, including extended-key distinction.</summary>
public sealed class Session
{
    private readonly HashSet<int> wanted, held=[];
    private readonly double created, limit;
    private double now, preparation, cleaning, drain;
    private double? hold;
    public Phase Phase { get; private set; }=Phase.Verifying;
    public string Reason { get; private set; }="";
    public double Progress => Phase==Phase.Draining ? 1 : Phase==Phase.Cleaning && hold.HasValue ? Math.Clamp((now-hold.Value)/5,0,1) : 0;
    public double Remaining => Phase==Phase.Preparing ? Math.Max(0,3-(now-preparation)) : Phase is Phase.Cleaning or Phase.Draining ? Math.Max(0,limit-(now-cleaning)) : 0;
    public bool Suppressing => Phase is Phase.Cleaning or Phase.Draining;
    public bool SuppressKeyboard => Phase is Phase.Verifying or Phase.Release or Phase.Cleaning or Phase.Draining;
    public double? CleaningStarted => Phase is Phase.Cleaning or Phase.Draining ? cleaning : null;
    public Session(IEnumerable<int> selected, double time, double maximumSeconds=180)
    {
        int[] keys=selected.ToArray(); wanted=new(keys);
        if(keys.Length!=4 || wanted.Count!=4 || keys.Any(x=>x<=0) || !double.IsFinite(time) || maximumSeconds is <=0 or >180 || !double.IsFinite(maximumSeconds)) throw new ArgumentException("Invalid session");
        created=now=time; limit=maximumSeconds;
    }
    public void Tick(double time) => Advance(time,true);
    private void Advance(double time, bool evaluateHold)
    {
        if(!double.IsFinite(time)) { Stop("clock"); return; }
        now=Math.Max(now,time);
        if(Phase is Phase.Verifying or Phase.Release or Phase.Preparing && now-created>=60) { Stop("verification-timeout"); return; }
        if(Phase==Phase.Preparing && now-preparation>=3) { Phase=Phase.Cleaning; cleaning=now; }
        if(Phase is Phase.Cleaning or Phase.Draining && now-cleaning>=limit) { Stop("timeout"); return; }
        if(evaluateHold && Phase==Phase.Cleaning && hold.HasValue && now-hold.Value>=5) { Phase=Phase.Draining; drain=now; }
        if(Phase==Phase.Draining && (held.Count==0 || now-drain>=1)) Stop("unlocked");
    }
    public void Key(int id, bool down, bool injected, double time)
    {
        // Activity on the countdown boundary still cancels before entering cleaning.
        if(Phase==Phase.Preparing) { now=Math.Max(now,time); Stop("preparation-cancelled"); return; }
        Advance(time,false);
        if(Phase==Phase.Ended || injected) return;
        if(down) { if(held.Count>=512) { Stop("input-overflow"); return; } held.Add(id); } else held.Remove(id);
        bool exact=held.SetEquals(wanted);
        if(Phase==Phase.Verifying && exact) Phase=Phase.Release;
        else if(Phase==Phase.Release) {
            if(down && !wanted.Contains(id)) Phase=Phase.Verifying;
            else if(held.Count==0) { Phase=Phase.Preparing; preparation=now; }
        }
        if(Phase==Phase.Cleaning) { if(exact) hold ??= now; else hold=null; }
        if(Phase==Phase.Draining && held.Count==0) Stop("unlocked");
        Advance(now,true);
    }
    public void Activity(double time)
    {
        if(Phase==Phase.Preparing) { Stop("preparation-cancelled"); return; }
        Tick(time);
    }
    public void Stop(string reason)
    {
        if(Phase==Phase.Ended) return;
        Reason=reason; Phase=Phase.Ended; hold=null; held.Clear();
    }
}
