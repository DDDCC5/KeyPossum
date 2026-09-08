namespace KeyPossum.Core;

public sealed record SessionView(Phase Phase, double Remaining, double Progress, string Reason, bool WasCleaning);

/// <summary>Single-session publication: a terminal state can never be replaced by a stale writer.</summary>
public sealed class SessionFeed
{
    private SessionView current=new(Phase.Verifying,0,0,"",false);
    public SessionView Read=>Volatile.Read(ref current);
    public bool TryPublish(SessionView observed, SessionView next)
    {
        if(observed.Phase==Phase.Ended)return false;
        return ReferenceEquals(Interlocked.CompareExchange(ref current,next,observed),observed);
    }
    public bool Publish(SessionView next)
    {
        while(true){var observed=Read;if(observed.Phase==Phase.Ended)return false;if(TryPublish(observed,next))return true;}
    }
}
