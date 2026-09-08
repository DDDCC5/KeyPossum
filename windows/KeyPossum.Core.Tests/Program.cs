using KeyPossum.Core;

int passed = 0;
void Test(string name, Action test) { test(); Console.WriteLine($"PASS {name}"); passed++; }
void Equal<T>(T expected, T actual) { if (!Equals(expected, actual)) throw new Exception($"Expected {expected}; actual {actual}"); }
void Throws(Action action) { try { action(); } catch (ArgumentException) { return; } throw new Exception("Expected rejection"); }
Session Ready(double limit = 180) {
    var s = new Session([1,2,3,4], 0, limit);
    foreach (int k in new[] {1,2,3,4}) s.Key(k, true, false, 0);
    foreach (int k in new[] {1,2,3,4}) s.Key(k, false, false, 0);
    s.Tick(3); Equal(Phase.Cleaning, s.Phase); return s;
}
void Chord(Session s, double time) { foreach (int k in new[] {1,2,3,4}) s.Key(k, true, false, time); }
Test("invalid custom codes and duplicate physical IDs are rejected", () => {
    foreach (var code in new[] {"AAAA", "ABC", "ABCO", "AB01", "abcd"}) Equal(false, Combination.IsValid(code));
    Equal(true, Combination.IsValid("AB23")); Throws(() => new Session([1,1,3,4], 0));
});
Test("no lock before exact chord and release", () => { var s = new Session([1,2,3,4],0); s.Tick(10); Equal(Phase.Verifying,s.Phase); Chord(s,10); s.Tick(20); Equal(Phase.Release,s.Phase); s.Key(1,false,false,20); s.Tick(24); Equal(Phase.Release,s.Phase); });
Test("extra key prevents qualification", () => { var s = new Session([1,2,3,4],0); s.Key(5,true,false,0); Chord(s,0); Equal(Phase.Verifying,s.Phase); });
Test("preparation input cancels", () => { var s = new Session([1,2,3,4],0); Chord(s,0); foreach(int k in new[]{1,2,3,4}) s.Key(k,false,false,0); s.Activity(2.99); s.Tick(3); Equal(Phase.Ended,s.Phase); });
Test("injected preparation input cancels", () => { var s = new Session([1,2,3,4],0); Chord(s,0); foreach(int k in new[]{1,2,3,4}) s.Key(k,false,false,0); s.Key(1,true,true,2); Equal(Phase.Ended,s.Phase); });
Test("five second hold boundary and release drain", () => { var s = Ready(); Chord(s,4); s.Tick(8.99); Equal(Phase.Cleaning,s.Phase); s.Tick(9); Equal(Phase.Draining,s.Phase); foreach(int k in new[]{1,2,3,4}) s.Key(k,false,false,9.1); Equal(Phase.Ended,s.Phase); });
Test("fifth key and modifiers reset progress", () => { var s = Ready(); Chord(s,4); s.Key(42,true,false,8); s.Key(42,false,false,8.1); s.Tick(12); Equal(Phase.Cleaning,s.Phase); s.Tick(13.1); Equal(Phase.Draining,s.Phase); });
Test("release resets and repeat does not reset", () => { var s = Ready(); Chord(s,4); s.Key(1,true,false,7); s.Tick(9); Equal(Phase.Draining,s.Phase); var r=Ready(); Chord(r,4); r.Key(1,false,false,8); r.Key(1,true,false,8.1); r.Tick(9); Equal(Phase.Cleaning,r.Phase); });
Test("injected keys never unlock", () => { var s = Ready(); foreach(int k in new[]{1,2,3,4}) s.Key(k,true,true,4); s.Tick(10); Equal(Phase.Cleaning,s.Phase); Equal(0d,s.Progress); });
Test("180 seconds restores even with held keys", () => { var s=Ready(); s.Key(1,true,false,170); s.Tick(182.99); Equal(Phase.Cleaning,s.Phase); s.Tick(183); Equal(Phase.Ended,s.Phase); Equal("timeout",s.Reason); });
Test("trial bounded at 15 seconds", () => { var s=Ready(15); s.Tick(18); Equal(Phase.Ended,s.Phase); });
Test("backward time cannot accelerate hold", () => { var s=Ready(); Chord(s,10); s.Tick(9); Equal(0d,s.Progress); s.Tick(14.99); Equal(Phase.Cleaning,s.Phase); s.Tick(15); Equal(Phase.Draining,s.Phase); });
Test("release drain cannot lock forever", () => { var s=Ready(); Chord(s,4); s.Tick(9); s.Tick(10); Equal(Phase.Ended,s.Phase); });
Test("verification itself expires", () => { var s=new Session([1,2,3,4],0); s.Tick(60); Equal(Phase.Ended,s.Phase); });
Test("stop idempotent", () => { var s=Ready(); s.Stop("failure"); s.Stop("second"); Equal("failure",s.Reason); Equal(Phase.Ended,s.Phase); });
Test("verification final release remains suppressed", () => { var s=new Session([1,2,3,4],0); Chord(s,0); foreach(int k in new[]{1,2,3})s.Key(k,false,false,0); Equal(true,s.SuppressKeyboard); s.Key(4,false,false,0); Equal(false,s.SuppressKeyboard); Equal(Phase.Preparing,s.Phase); });
Test("exact preparation boundary input cancels instead of locking",()=>{var s=new Session([1,2,3,4],0);Chord(s,0);foreach(int k in new[]{1,2,3,4})s.Key(k,false,false,0);s.Key(5,true,false,3);Equal(Phase.Ended,s.Phase);Equal("preparation-cancelled",s.Reason);});
Test("random combinations always usable",()=>{for(int i=0;i<1000;i++)Equal(true,Combination.IsValid(Combination.Random()));});
Test("fifth key at five-second boundary resets before hold evaluation",()=>{var s=Ready();Chord(s,4);s.Key(5,true,false,9);Equal(Phase.Cleaning,s.Phase);Equal(0d,s.Progress);});
Test("late extra key event cannot complete a stale chord",()=>{var s=Ready();Chord(s,4);s.Key(5,true,false,10);Equal(Phase.Cleaning,s.Phase);Equal(0d,s.Progress);});
Test("release at five-second boundary resets before hold evaluation",()=>{var s=Ready();Chord(s,4);s.Key(1,false,false,9);Equal(Phase.Cleaning,s.Phase);Equal(0d,s.Progress);});
Test("terminal snapshot rejects stale cleaning publication",()=>{var feed=new SessionFeed();var observed=feed.Read;var stale=new SessionView(Phase.Cleaning,100,0,"",true);feed.Publish(new(Phase.Ended,0,0,"failure",true));Equal(false,feed.TryPublish(observed,stale));Equal(false,feed.Publish(stale));Equal(Phase.Ended,feed.Read.Phase);Equal("failure",feed.Read.Reason);});
Console.WriteLine($"{passed} tests passed.");
