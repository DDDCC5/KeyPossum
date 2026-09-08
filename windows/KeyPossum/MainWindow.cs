using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using KeyPossum.Core;

namespace KeyPossum;

internal sealed class MainWindow : Window
{
    internal static InputController? ActiveController {get;private set;}
    private readonly bool zh=CultureInfo.CurrentUICulture.TwoLetterISOLanguageName=="zh";
    private readonly Settings settings=Settings.Load();
    private readonly TextBox code=new(){MaxLength=4,CharacterCasing=CharacterCasing.Upper,FontSize=28,TextAlignment=TextAlignment.Center,Padding=new Thickness(8),Margin=new Thickness(0,8,0,6)};
    private readonly TextBlock status=new(){TextWrapping=TextWrapping.Wrap,TextAlignment=TextAlignment.Center,FontSize=15,MinHeight=66,Margin=new Thickness(0,10,0,0)};
    private readonly TextBlock badge=new(){TextAlignment=TextAlignment.Center,FontSize=12,Margin=new Thickness(0,4,0,4)};
    private readonly TextBlock remaining=new(){TextAlignment=TextAlignment.Center,FontSize=20};
    private readonly Ring ring=new(){Width=138,Height=138};
    private readonly Button start=new(), trial=new(), random=new(), cancel=new(), reset=new(), passed=new(), failed=new();
    private readonly StackPanel results=new(){Visibility=Visibility.Collapsed};
    private readonly DispatcherTimer timer;
    private Capability? capability;
    private string? trialFingerprint;
    private bool isTrial, customEdited, changing, notificationReady;
    private nint hwnd;
    private string T(string en,string cn)=>zh?cn:en;
    internal MainWindow()
    {
        Title="KeyPossum"; Width=420; Height=740; MinWidth=390; MinHeight=690;
        ResizeMode=ResizeMode.CanMinimize; WindowStartupLocation=WindowStartupLocation.CenterScreen; Topmost=true;
        Background=new SolidColorBrush(Color.FromRgb(250,247,240)); Foreground=new SolidColorBrush(Color.FromRgb(56,47,68));
        FontFamily=new FontFamily("Segoe UI, Microsoft YaHei UI");
        var root=new StackPanel{Margin=new Thickness(28,18,28,18)};
        Content=new ScrollViewer{Content=root,VerticalScrollBarVisibility=ScrollBarVisibility.Auto};
        var header=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Center};
        try {
            var icon=new BitmapImage(new Uri("pack://application:,,,/keypossum.png")); Icon=icon;
            header.Children.Add(new Image{Source=icon,Width=52,Height=52,Margin=new Thickness(0,0,10,0)});
        } catch { /* The source build can compile before artwork is installed. */ }
        header.Children.Add(new TextBlock{Text="KeyPossum",FontSize=26,FontWeight=FontWeights.SemiBold,VerticalAlignment=VerticalAlignment.Center});
        root.Children.Add(header);
        root.Children.Add(new TextBlock{Text=T("A little pause for a cleaner keyboard.","让键盘歇一会儿，干干净净再出发。"),TextAlignment=TextAlignment.Center,Margin=new Thickness(0,5,0,8)});
        root.Children.Add(badge); root.Children.Add(ring); root.Children.Add(remaining); root.Children.Add(status);
        root.Children.Add(code);
        code.TextChanged+=(_,_)=>{if(!changing) customEdited=true;};
        SetCode(settings.CustomCode??Combination.Random());
        Configure(random,T("New random combination","随机换一组"),()=>{SetCode(Combination.Random());settings.CustomCode=null;customEdited=false;Save();});
        root.Children.Add(random);
        Configure(start,T("Verify keys → clean (3 minutes)","验证组合键 → 清洁（3 分钟）"),()=>Begin(false));
        Configure(trial,T("Run capability TEST (15 seconds)","运行能力测试（15 秒）"),()=>Begin(true));
        Configure(cancel,T("Cancel / restore input","取消 / 恢复输入"),()=>ActiveController?.Stop("cancelled"));
        root.Children.Add(start); root.Children.Add(trial); root.Children.Add(cancel);
        results.Children.Add(new TextBlock{Text=T("After the trial: did you test pointer, buttons, wheel, taps, all trackpad gestures, media keys, external devices and elevated windows, with no leakage?","测试后确认：已检查指针、鼠标按键和滚轮、触控板点按及全部手势、媒体键、外接设备与管理员窗口，且均无输入泄漏？"),TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,8,0,4)});
        Configure(passed,T("Yes — all applicable paths passed","是，全部适用输入方式均通过"),ConfirmTrial);
        Configure(failed,T("A path leaked / I am not sure","存在泄漏 / 尚不确定"),()=>{settings.QualifiedFingerprint=null;Save();results.Visibility=Visibility.Collapsed;status.Text=T("Normal cleaning is blocked. Fix the unsupported path, then repeat the test.","正常清洁已禁用。解决未支持的输入路径后，请重新测试。");RefreshCapability();});
        results.Children.Add(passed); results.Children.Add(failed); root.Children.Add(results);
        Configure(reset,T("Reset device qualification","清除设备测试确认"),()=>{settings.QualifiedFingerprint=null;Save();RefreshCapability();});root.Children.Add(reset);
        root.Children.Add(new TextBlock{Text=T("Offline · no key logs · alpha\nPower, Ctrl+Alt+Delete and secure desktops remain system controlled. Touch / pen / remote sessions unsupported.","离线 · 不记录按键 · Alpha\n电源、Ctrl+Alt+Delete 与安全桌面仍由系统控制。暂不支持触摸屏、笔输入及远程会话。"),TextWrapping=TextWrapping.Wrap,TextAlignment=TextAlignment.Center,FontSize=11,Foreground=Brushes.DimGray,Margin=new Thickness(0,10,0,0)});
        timer=new DispatcherTimer{Interval=TimeSpan.FromMilliseconds(100)}; timer.Tick+=(_,_)=>Update();timer.Start();
        SourceInitialized+=(_,_)=>{hwnd=new WindowInteropHelper(this).Handle;HwndSource.FromHwnd(hwnd).AddHook(WindowMessage);notificationReady=Native.WTSRegisterSessionNotification(hwnd,0);RefreshCapability();};
        Closing+=(_,_)=>{ActiveController?.Dispose();timer.Stop();if(hwnd!=0)Native.WTSUnRegisterSessionNotification(hwnd);};
    }
    private void Configure(Button button,string label,Action action)
    {
        button.Content=label;button.Padding=new Thickness(10,7,10,7);button.Margin=new Thickness(0,3,0,3);
        button.Background=new SolidColorBrush(Color.FromRgb(224,214,243));button.BorderBrush=new SolidColorBrush(Color.FromRgb(198,182,223));
        button.Click+=(_,_)=>action();
    }
    private void SetCode(string value){changing=true;code.Text=value;changing=false;}
    private bool Save(){try{settings.Save();return true;}catch{status.Text=T("Local settings could not be saved.","无法保存本地设置。");return false;}}
    private void RefreshCapability()
    {
        try {
            if(!notificationReady)throw new InvalidOperationException("capability");
            capability=Capabilities.Inspect();
            if(settings.QualifiedFingerprint!=capability.Fingerprint){settings.QualifiedFingerprint=null;Save();}
            bool qualified=settings.QualifiedFingerprint==capability.Fingerprint;
            badge.Text=qualified?T("MANUALLY QUALIFIED · same device configuration","已人工测试确认 · 当前设备配置"):T("UNQUALIFIED · test required before cleaning","尚未确认 · 清洁前必须测试");
            start.IsEnabled=qualified;trial.IsEnabled=true;
            if(ActiveController is null)status.Text=T("Choose four keys. You will press them together, release all keys, then wait 3 seconds.","选定四个键。先同时按下以验证，松开所有按键，然后等待 3 秒。");
        } catch(Exception e){capability=null;settings.QualifiedFingerprint=null;Save();start.IsEnabled=trial.IsEnabled=false;badge.Text=T("UNSUPPORTED / UNKNOWN CAPABILITY","不支持 / 无法确定设备能力");status.Text=Error(e.Message);}
        cancel.IsEnabled=false;
    }
    private void Begin(bool test)
    {
        if(ActiveController is not null)return;
        if(!Combination.IsValid(code.Text)){status.Text=T("Use four different uppercase letters or digits, excluding O, 0, I, 1.","请输入四个不同的大写字母或数字，不含 O、0、I、1。");return;}
        RefreshCapability();if(capability is null || (!test && settings.QualifiedFingerprint!=capability.Fingerprint))return;
        if(test){settings.QualifiedFingerprint=null;if(!Save())return;}
        if(customEdited){settings.CustomCode=code.Text;if(!Save())return;customEdited=false;}
        settings.SessionActive=true;if(!Save()){settings.SessionActive=false;return;}
        isTrial=test;trialFingerprint=capability.Fingerprint;results.Visibility=Visibility.Collapsed;
        ActiveController=new InputController(code.Text,capability,test);
        foreach(var b in new[]{start,trial,random,reset})b.IsEnabled=false;
        cancel.IsEnabled=true;code.IsReadOnly=true;KeyboardFocus();ActiveController.Start();
    }
    private void KeyboardFocus(){Focus();System.Windows.Input.Keyboard.ClearFocus();}
    private void Update()
    {
        var controller=ActiveController;if(controller is null)return;
        controller.Heartbeat();var s=controller.Snapshot;ring.Progress=s.Progress;
        badge.Text=isTrial?T("CAPABILITY TEST · coverage not yet confirmed","能力测试 · 输入覆盖尚未确认"):T("CLEANING SESSION · manually qualified","清洁会话 · 已人工测试确认");
        remaining.Text=s.Phase is Phase.Preparing or Phase.Cleaning ? $"{Math.Ceiling(s.Remaining):0} s" : "";
        status.Text=s.Phase switch {
            Phase.Verifying=>T("Press exactly these four physical keys together. Keyboard input is held during verification; the mouse can cancel.","同时按下且仅按下这四个实体键。验证期间拦截键盘，仍可用鼠标取消。"),
            Phase.Release=>T("Combination recognized. Release every key.","组合键已识别。请松开所有按键。"),
            Phase.Preparing=>T("Hands off for 3 seconds. Any input cancels.","请停止操作 3 秒。任何输入都会取消。"),
            Phase.Cleaning=>isTrial?T("TEST: try every input path. Hold the four keys for 5 seconds to end early.","测试中：请尝试所有输入方式。持续按住四键 5 秒可提前结束。"):T("Clean gently. Hold exactly the four keys for 5 seconds to restore input.","轻柔清洁。仅持续按住这四个键 5 秒以恢复输入。"),
            Phase.Draining=>T("Unlocked. Release all four keys…","已解锁，请松开四个键……"),
            _=>Error(s.Reason)
        };
        if(s.Phase!=Phase.Ended)return;
        controller.Dispose();ActiveController=null;code.IsReadOnly=false;random.IsEnabled=reset.IsEnabled=true;
        settings.SessionActive=false;Save();
        string ended=status.Text;RefreshCapability();status.Text=ended;
        if(s.Reason is not ("unlocked" or "timeout" or "cancelled" or "preparation-cancelled" or "verification-timeout")){
            settings.QualifiedFingerprint=null;Save();RefreshCapability();status.Text=ended;
        }
        if(isTrial && s.WasCleaning && s.Reason is "timeout" or "unlocked"){
            results.Visibility=Visibility.Visible;Height=850;
        }
    }
    private void ConfirmTrial()
    {
        try {
            var current=Capabilities.Inspect();
            if(trialFingerprint is null || current.Fingerprint!=trialFingerprint)throw new InvalidOperationException("devices");
            settings.QualifiedFingerprint=current.Fingerprint;
            if(!Save()){settings.QualifiedFingerprint=null;return;}
            results.Visibility=Visibility.Collapsed;Height=740;RefreshCapability();
        }catch(Exception e){settings.QualifiedFingerprint=null;Save();status.Text=Error(e.Message);}
    }
    private nint WindowMessage(nint h,int message,nint w,nint l,ref bool handled)
    {
        if(message is 0x219 or 0x2b1 or 0x218 or 0x11 || (message==0x1c && w==0 && ActiveController?.Snapshot.Phase is Phase.Cleaning or Phase.Draining)){
            ActiveController?.Stop(message==0x219?"devices":"session");
            if(message==0x219){settings.QualifiedFingerprint=null;Save();if(ActiveController is null)RefreshCapability();}
        }
        return 0;
    }
    private string Error(string reason)=>reason switch {
        "unlocked"=>T("Input restored. Ready when you are.","输入已恢复，随时可以再次开始。"),
        "timeout"=>T("Time is up. Input restored automatically.","时间已到，输入已自动恢复。"),
        "preparation-cancelled"=>T("Preparation cancelled by input. Try again when ready.","检测到输入，准备已取消。就绪后可重试。"),
        "cancelled"=>T("Cancelled. Input restored.","已取消，输入已恢复。"),
        "verification-timeout"=>T("Verification expired. Input restored.","验证超时，输入已恢复。"),
        "touch"=>T("Touchscreen / pen input is unsupported. Cleaning is blocked.","暂不支持触摸屏或笔输入，已禁止清洁。"),
        "platform"=>T("Windows 11 on Intel / AMD x64 is required.","需要 Windows 11，Intel / AMD x64 电脑。"),
        "remote"=>T("Remote sessions are unsupported. Use the local desktop.","暂不支持远程会话，请使用本机桌面。"),
        "release-initial"=>T("Release all keys and mouse buttons, then retry.","请松开全部键盘及鼠标按键，然后重试。"),
        "devices"=>T("Device configuration changed. Input restored; test again.","设备配置已变化，输入已恢复，请重新测试。"),
        _=>T("Protection ended or could not start. Input is released. Check the local desktop and devices, then repeat capability testing.","保护已结束或无法启动，输入已释放。请检查本机桌面与设备，然后重新运行能力测试。")
    };
}

internal sealed class Ring : FrameworkElement
{
    private double progress;
    internal double Progress{get=>progress;set{progress=Math.Clamp(value,0,1);InvalidateVisual();}}
    protected override void OnRender(DrawingContext dc)
    {
        var center=new Point(ActualWidth/2,ActualHeight/2);double radius=Math.Min(ActualWidth,ActualHeight)/2-9;
        dc.DrawEllipse(null,new Pen(new SolidColorBrush(Color.FromRgb(232,224,240)),9),center,radius,radius);
        if(progress<=0)return;
        var geometry=new StreamGeometry();using(var c=geometry.Open()){
            c.BeginFigure(new Point(center.X,center.Y-radius),false,false);
            for(int i=1;i<=100;i++){double a=-Math.PI/2+Math.PI*2*progress*i/100;c.LineTo(new Point(center.X+radius*Math.Cos(a),center.Y+radius*Math.Sin(a)),true,false);}
        }
        dc.DrawGeometry(null,new Pen(new SolidColorBrush(Color.FromRgb(143,111,184)),9){StartLineCap=PenLineCap.Round,EndLineCap=PenLineCap.Round},geometry);
    }
}
