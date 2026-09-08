using System.Windows;

namespace KeyPossum;
internal static class Program
{
    [STAThread] private static int Main(string[] args)
    {
        if(args.Length>0 && args[0]=="--supervise") return SafetyGate.Supervise(args);
        using var instance=new Mutex(true,"Local\\KeyPossum-Application",out bool first);
        if(!first){MessageBox.Show("KeyPossum is already running. / KeyPossum 已在运行。","KeyPossum");return 0;}
        var app=new Application();
        app.DispatcherUnhandledException+=(_,e)=> { MainWindow.ActiveController?.Stop("ui-failure"); e.Handled=false; };
        app.Exit+=(_,_)=>MainWindow.ActiveController?.Dispose();
        return app.Run(new MainWindow());
    }
}
