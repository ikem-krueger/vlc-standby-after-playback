<#
Add-Type -TypeDefinition @"
    using System;
    using System.Windows.Forms;

    public class TrayTip {
        public static void Show(string title, string text, int timeout) {
            NotifyIcon trayIcon = new NotifyIcon();
            trayIcon.Visible = true;
            trayIcon.Icon = SystemIcons.Information;
            trayIcon.BalloonTipTitle = title;
            trayIcon.BalloonTipText = text;
            trayIcon.ShowBalloonTip(timeout);
        }
    }
"@
[TrayTip]::Show("VLC standby bootstrapper", "The bootstrapper is listening for VLC windows...", 10)
#>

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class NativeFunctions
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int MessageBoxTimeout(IntPtr hWnd, string lpText, string lpCaption, uint uType, Int16 wLanguageId, Int32 dwMilliseconds);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr GetForegroundWindow();
}
"@

$TIMEOUT = 20 # seconds

$MB_ICONINFORMATION = 0x40
$MB_YESNO = 0x4
$MB_TITLE = "Standby in progress"
$MB_TEXT = "This PC is going into standby in $TIMEOUT seconds.`n`nDo you want to abort this action?"

$IDYES = 6

Function Trigger-Standby {
  Add-Type -Assembly System.Windows.Forms

  $State = [System.Windows.Forms.PowerState]::Suspend

  [System.Windows.Forms.Application]::SetSuspendState($State, $False, $False) | Out-Null
}

Function Main {
    $vlcProcess = $Null

    $previousState = ""
    $actualState = ""

    While($true) {
        Start-Sleep -Milliseconds 1000

        try {
            # Running
            $vlcProcess = Get-Process -Name "vlc" -ErrorAction Stop

            If($vlcProcess.mainWindowTitle -match ".+VLC media player") {
                $actualState = "Playing"
            }

            If($vlcProcess.mainWindowTitle -eq "VLC media player") {
                $actualState = "Idle"
            }
        } catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
            # Closed
            break
        }

        If($previousState -eq "Playing" -and $actualState -eq "Idle") {
            $choice = [NativeFunctions]::MessageBoxTimeout([NativeFunctions]::GetForegroundWindow(), $MB_TEXT, $MB_TITLE, $MB_ICONINFORMATION -bor $MB_YESNO, 0, $TIMEOUT * 1000)

            If ($choice -eq $IDYES) {
                break
            }

            Write-Host "Close VLC..."

            Stop-Process -Name "vlc" -Force

            Write-Host "Trigger standby..."

            Trigger-Standby
        }

        If($previousState -ne $actualState) {
            Write-Host "State: $actualState"

            $previousState = $actualState
        }
    }

    Main
}

Write-Host "VLC standby"

Main
