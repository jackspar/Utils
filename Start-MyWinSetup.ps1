#Requires -Version 5.1
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$scriptRoot = $PSScriptRoot

# UAC elevation -- re-launch as admin if needed
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process powershell -Verb RunAs `
        -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    exit
}

# Detect environment
$cs      = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$isVM    = $cs.Manufacturer -like "*VMware*" -or
           $cs.Manufacturer -like "*VirtualBox*" -or
           ($cs.Manufacturer -like "*Microsoft*" -and $cs.Model -like "*Virtual*")
$build   = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
$isWin11 = $build -ge 22000
$isArm64 = $env:PROCESSOR_ARCHITECTURE -eq 'ARM64'
$osStr   = "$(if ($isWin11){'Windows 11'}else{'Windows 10'})  ·  " +
           "$(if ($isArm64){'ARM64'}else{'x64'})  ·  " +
           "$(if ($isVM){'VM detected — Core Temp + Macrium skipped'}else{'Bare metal'})"
$epArch  = if ($isArm64) { 'ARM64' } else { 'x64' }

# Shared state for cross-runspace UI updates
$sync = [hashtable]::Synchronized(@{})

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MyWin-Setup" Height="580" Width="464"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        Background="#1A1A1A" FontFamily="Segoe UI" FontSize="13">
  <Grid Margin="20,16,20,16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="4"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Margin="0,0,0,14">
      <TextBlock Text="MyWin Setup" FontSize="18" FontWeight="SemiBold" Foreground="#FFFFFF"/>
      <TextBlock x:Name="OsInfo" FontSize="11" Foreground="#606060" Margin="0,3,0,0"/>
    </StackPanel>

    <TextBlock Grid.Row="1" Text="SELECT COMPONENTS" FontSize="10" Foreground="#505050"
               FontWeight="Bold" Margin="0,0,0,8"/>

    <StackPanel Grid.Row="2">
      <CheckBox x:Name="cb8Gadget"    Margin="0,4" Foreground="#C8C8C8">
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="8GadgetPack" Foreground="#C8C8C8"/>
          <TextBlock Text="  v31" Foreground="#555555"/>
        </StackPanel>
      </CheckBox>
      <CheckBox x:Name="cbEP"         Margin="0,4" Foreground="#C8C8C8">
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="ExplorerPatcher" Foreground="#C8C8C8"/>
          <TextBlock x:Name="EpArch" Foreground="#555555"/>
        </StackPanel>
      </CheckBox>
      <CheckBox x:Name="cbOpenShell"  Margin="0,4" Content="Open Shell"      Foreground="#C8C8C8"/>
      <CheckBox x:Name="cbCoreTemp"   Margin="0,4" Foreground="#C8C8C8">
        <StackPanel Orientation="Horizontal">
          <TextBlock x:Name="CtText" Foreground="#C8C8C8"/>
        </StackPanel>
      </CheckBox>
      <CheckBox x:Name="cbMacrium"    Margin="0,4" Foreground="#C8C8C8">
        <StackPanel Orientation="Horizontal">
          <TextBlock x:Name="MacText" Foreground="#C8C8C8"/>
        </StackPanel>
      </CheckBox>
      <Rectangle Height="1" Fill="#2A2A2A" Margin="0,8,0,4"/>
      <CheckBox x:Name="cbWinConfig"  Margin="0,4" Content="Apply registry config (dark theme, privacy, power, bloat)"
                Foreground="#C8C8C8"/>
      <CheckBox x:Name="cbSettings"   Margin="0,4" Content="Restore app settings (EP, Open Shell, gadgets)"
                Foreground="#C8C8C8"/>
    </StackPanel>

    <Border Grid.Row="3" Background="#111111" CornerRadius="4" Margin="0,12,0,0"
            BorderBrush="#2A2A2A" BorderThickness="1">
      <ScrollViewer x:Name="LogScroll" VerticalScrollBarVisibility="Auto">
        <TextBox x:Name="LogBox" Background="Transparent" Foreground="#888888"
                 FontFamily="Consolas" FontSize="11" IsReadOnly="True"
                 BorderThickness="0" Padding="8,6" TextWrapping="Wrap" AcceptsReturn="True"
                 Text="Ready. Select components above, then click Install."/>
      </ScrollViewer>
    </Border>

    <ProgressBar x:Name="ProgBar" Grid.Row="4" Height="3" Margin="0,6,0,0"
                 Background="#222222" Foreground="#0078D4" BorderThickness="0"
                 Visibility="Collapsed"/>

    <Grid Grid.Row="6" Margin="0,10,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="8"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBlock x:Name="StatusTxt" Grid.Column="0" Text="Ready" Foreground="#505050"
                 VerticalAlignment="Center" FontSize="12"/>
      <Button x:Name="CancelBtn" Grid.Column="1" Content="Cancel" Padding="16,7"
              Background="#252525" Foreground="#A0A0A0" BorderBrush="#383838"
              BorderThickness="1" Cursor="Hand"/>
      <Button x:Name="InstallBtn" Grid.Column="3" Content="Install  →" Padding="16,7"
              Background="#0078D4" Foreground="White" BorderThickness="0" Cursor="Hand"/>
    </Grid>
  </Grid>
</Window>
'@

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$elOsInfo     = $window.FindName('OsInfo')
$elEpArch     = $window.FindName('EpArch')
$elCtText     = $window.FindName('CtText')
$elMacText    = $window.FindName('MacText')
$cb8          = $window.FindName('cb8Gadget')
$cbEP         = $window.FindName('cbEP')
$cbOS         = $window.FindName('cbOpenShell')
$cbCT         = $window.FindName('cbCoreTemp')
$cbMac        = $window.FindName('cbMacrium')
$cbWC         = $window.FindName('cbWinConfig')
$cbSet        = $window.FindName('cbSettings')
$logBox       = $window.FindName('LogBox')
$logScroll    = $window.FindName('LogScroll')
$progBar      = $window.FindName('ProgBar')
$statusTxt    = $window.FindName('StatusTxt')
$installBtn   = $window.FindName('InstallBtn')
$cancelBtn    = $window.FindName('CancelBtn')

# Populate dynamic labels
$elOsInfo.Text  = $osStr
$elEpArch.Text  = "  $epArch"

if ($isVM) {
    $cbCT.IsChecked   = $false
    $cbMac.IsChecked  = $false
    $elCtText.Text    = 'Core Temp v1.18.1  [VM — skipped]'
    $elMacText.Text   = 'Macrium Reflect v7  [VM — skipped]'
    $elCtText.Foreground   = '#505050'
    $elMacText.Foreground  = '#505050'
} else {
    $cbCT.IsChecked   = $true
    $cbMac.IsChecked  = $true
    $elCtText.Text    = 'Core Temp v1.18.1'
    $elMacText.Text   = 'Macrium Reflect v7'
}
$cb8.IsChecked  = $true
$cbEP.IsChecked = $true
$cbOS.IsChecked = $true
$cbWC.IsChecked = $true
$cbSet.IsChecked = $true

$sync.Window     = $window
$sync.LogBox     = $logBox
$sync.LogScroll  = $logScroll
$sync.ProgBar    = $progBar
$sync.StatusTxt  = $statusTxt
$sync.InstallBtn = $installBtn
$sync.CancelBtn  = $cancelBtn

$cancelBtn.Add_Click({ $window.Close() })

$installBtn.Add_Click({
    # Capture checkbox state before background runspace runs
    $opts = @{
        Do8Gadget   = [bool]$cb8.IsChecked
        DoEP        = [bool]$cbEP.IsChecked
        DoOpenShell = [bool]$cbOS.IsChecked
        DoCoreTemp  = [bool]$cbCT.IsChecked
        DoMacrium   = [bool]$cbMac.IsChecked
        DoWinConfig = [bool]$cbWC.IsChecked
        DoSettings  = [bool]$cbSet.IsChecked
    }

    $installBtn.IsEnabled = $false
    $cancelBtn.IsEnabled  = $false
    $progBar.Visibility   = 'Visible'
    $progBar.IsIndeterminate = $true
    $logBox.Text = ''
    $statusTxt.Text = 'Running...'

    # Build Install-CoreApps.ps1 argument list
    $installArgs = @('-BundleRoot', "$scriptRoot\CoreApps-Bundle")
    if (!$opts.Do8Gadget)   { $installArgs += '-Skip8GadgetPack' }
    if (!$opts.DoEP)        { $installArgs += '-SkipExplorerPatcher' }
    if (!$opts.DoOpenShell) { $installArgs += '-SkipOpenShell' }
    if (!$opts.DoCoreTemp)  { $installArgs += '-SkipCoreTemp' }
    if (!$opts.DoMacrium)   { $installArgs += '-SkipMacrium' }
    if (!$opts.DoSettings)  { $installArgs += '-SkipSettings' }

    # Run in background runspace so UI stays responsive
    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('sync',        $sync)
    $rs.SessionStateProxy.SetVariable('scriptRoot',  $scriptRoot)
    $rs.SessionStateProxy.SetVariable('opts',        $opts)
    $rs.SessionStateProxy.SetVariable('installArgs', $installArgs)

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
        function Log([string]$text) {
            $sync.Window.Dispatcher.Invoke([Action]{
                $sync.LogBox.AppendText("$text`n")
                $sync.LogBox.ScrollToEnd()
            })
        }

        try {
            if ($opts.DoWinConfig) {
                Log '-- Apply-WinConfig ----------------------------------------'
                & "$scriptRoot\Apply-WinConfig.ps1" *>&1 | ForEach-Object { Log "  $_" }
                Log ''
            }

            $anyAppOrSettings = $opts.Do8Gadget -or $opts.DoEP -or $opts.DoOpenShell -or
                                $opts.DoCoreTemp -or $opts.DoMacrium -or $opts.DoSettings
            if ($anyAppOrSettings) {
                Log '-- Install-CoreApps ----------------------------------------'
                & "$scriptRoot\Install-CoreApps.ps1" @installArgs *>&1 | ForEach-Object { Log "  $_" }
                Log ''
            }

            Log 'Done. Reboot to apply shell changes (ExplorerPatcher).'
            $sync.Window.Dispatcher.Invoke([Action]{
                $sync.ProgBar.IsIndeterminate = $false
                $sync.ProgBar.Value = 100
                $sync.StatusTxt.Text = 'Done — reboot when ready.'
                $sync.InstallBtn.Content = 'Close'
                $sync.InstallBtn.IsEnabled = $true
                $sync.InstallBtn.Add_Click({ $sync.Window.Close() })
            })
        } catch {
            Log "ERROR: $_"
            $sync.Window.Dispatcher.Invoke([Action]{
                $sync.ProgBar.IsIndeterminate = $false
                $sync.StatusTxt.Text = 'Failed — see log.'
                $sync.InstallBtn.Content = 'Close'
                $sync.InstallBtn.IsEnabled = $true
                $sync.InstallBtn.Add_Click({ $sync.Window.Close() })
            })
        }
    })

    [void]$ps.BeginInvoke()
})

[void]$window.ShowDialog()
