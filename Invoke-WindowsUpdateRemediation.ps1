#Requires -Version 5.1
<#
.SYNOPSIS
    Windows Update Remediation Tool - Automated remediation and repair utility.
.DESCRIPTION
    Fixes common Windows Update issues by cleaning caches, resetting services,
    and running diagnostics. Includes a modern WinForms GUI with 10 selectable steps.
.AUTHOR
    Mert Ozsoy
.WEBSITE
    https://mertozsoy.com/
.LINKEDIN
    https://www.linkedin.com/in/mertozsoy365/
.YOUTUBE
    https://www.youtube.com/@mertozsoy365
.GITHUB
    https://github.com/mertozsoy
.VERSION
    1.0.0
.DATE
    2026-07-19
#>

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "This tool must be run as Administrator.`n`nPlease relaunch the application with `"Run as administrator`" option.",
        "Administrator Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$C_Primary      = [System.Drawing.ColorTranslator]::FromHtml("#0061a4")
$C_PrimaryCont  = [System.Drawing.ColorTranslator]::FromHtml("#2196f3")
$C_Secondary    = [System.Drawing.ColorTranslator]::FromHtml("#006e1c")
$C_Error        = [System.Drawing.ColorTranslator]::FromHtml("#ba1a1a")
$C_Warning      = [System.Drawing.ColorTranslator]::FromHtml("#FF9800")
$C_Bg           = [System.Drawing.ColorTranslator]::FromHtml("#f9f9f9")
$C_Surface      = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$C_Border       = [System.Drawing.ColorTranslator]::FromHtml("#D1D1D1")
$C_TextPrimary  = [System.Drawing.ColorTranslator]::FromHtml("#212121")
$C_TextMuted    = [System.Drawing.ColorTranslator]::FromHtml("#757575")
$C_Disabled     = [System.Drawing.ColorTranslator]::FromHtml("#9E9E9E")
$C_OnSurfVar    = [System.Drawing.ColorTranslator]::FromHtml("#404752")
$C_RowHL        = [System.Drawing.ColorTranslator]::FromHtml("#E8F5E9")
$C_SurfaceCont  = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")
$C_SurfaceLow   = [System.Drawing.ColorTranslator]::FromHtml("#f3f3f3")
$C_White        = [System.Drawing.Color]::White

$script:LogDir  = "C:\Temp"
$script:LogFile = "$script:LogDir\WinUpdate_Remediation.log"
$script:IsRunning   = $false
$script:ShouldCancel = $false
$script:ErrorCount  = 0
$script:StartTime   = $null

if (-not (Test-Path -LiteralPath $script:LogDir)) {
    try { New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null } catch {}
}

function Write-UILog {
    param([string]$Message)
    $time = Get-Date -Format "HH:mm:ss"
    if ($txtLog -and -not $txtLog.IsDisposed) {
        $txtLog.AppendText("[$time] $Message`r`n")
        $txtLog.SelectionStart = $txtLog.TextLength
        $txtLog.ScrollToCaret()
    }
    try { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" | Out-File -FilePath $script:LogFile -Append -Encoding UTF8 } catch {}
}

function Refresh-UI { [System.Windows.Forms.Application]::DoEvents() }

function Invoke-Step1 {
    Write-UILog "Step 1/10 - Clearing Windows Update policies..."
    $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (Test-Path $Path) { Remove-Item -Path $Path -Recurse -Verbose -ErrorAction SilentlyContinue; Write-UILog "  Deleted: $Path" } else { Write-UILog "  Not found: $Path" }
    $key = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings"
    if (Test-Path $key) {
        $val = Get-Item $key -EA Ignore; $props = $val.Property
        if ($props -contains "PausedQualityDate") { Remove-ItemProperty -Path $key -Name "PausedQualityDate" -Verbose -ErrorAction SilentlyContinue; Write-UILog "  Cleared: PausedQualityDate" }
        if ($props -contains "PausedFeatureDate") { Remove-ItemProperty -Path $key -Name "PausedFeatureDate" -Verbose -ErrorAction SilentlyContinue; Write-UILog "  Cleared: PausedFeatureDate" }
        if ($props -contains "PausedQualityStatus") { $v = $val.GetValue("PausedQualityStatus"); if ($v -ne "0") { Set-ItemProperty -Path $key -Name "PausedQualityStatus" -Value "0" -Verbose; Write-UILog "  Reset: PausedQualityStatus (old: $v)" } else { Write-UILog "  Already 0: PausedQualityStatus" } }
        if ($props -contains "PausedFeatureStatus") { $v = $val.GetValue("PausedFeatureStatus"); if ($v -ne "0") { Set-ItemProperty -Path $key -Name "PausedFeatureStatus" -Value "0" -Verbose; Write-UILog "  Reset: PausedFeatureStatus (old: $v)" } else { Write-UILog "  Already 0: PausedFeatureStatus" } }
    } else { Write-UILog "  Not found: $key" }
    $key2 = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update"
    if (Test-Path $key2) {
        $val2 = Get-Item $key2 -EA Ignore; $props2 = $val2.Property
        if ($props2 -contains "PauseQualityUpdatesStartTime") { Remove-ItemProperty -Path $key2 -Name "PauseQualityUpdatesStartTime" -Verbose -ErrorAction SilentlyContinue; Remove-ItemProperty -Path $key2 -Name "PauseQualityUpdatesStartTime_ProviderSet" -Verbose -ErrorAction SilentlyContinue; Remove-ItemProperty -Path $key2 -Name "PauseQualityUpdatesStartTime_WinningProvider" -Verbose -ErrorAction SilentlyContinue; Write-UILog "  Cleared: PauseQualityUpdatesStartTime" }
        if ($props2 -contains "PauseFeatureUpdatesStartTime") { Remove-ItemProperty -Path $key2 -Name "PauseFeatureUpdatesStartTime" -Verbose -ErrorAction SilentlyContinue; Remove-ItemProperty -Path $key2 -Name "PauseFeatureUpdatesStartTime_ProviderSet" -Verbose -ErrorAction SilentlyContinue; Remove-ItemProperty -Path $key2 -Name "PauseFeatureUpdatesStartTime_WinningProvider" -Verbose -ErrorAction SilentlyContinue; Write-UILog "  Cleared: PauseFeatureUpdatesStartTime" }
        if ($props2 -contains "PauseQualityUpdates") { $v = $val2.GetValue("PauseQualityUpdates"); if ($v -ne "0") { Set-ItemProperty -Path $key2 -Name "PauseQualityUpdates" -Value "0" -Verbose; Write-UILog "  Reset: PauseQualityUpdates (old: $v)" } else { Write-UILog "  Already 0: PauseQualityUpdates" } }
        if ($props2 -contains "PauseFeatureUpdates") { $v = $val2.GetValue("PauseFeatureUpdates"); if ($v -ne "0") { Set-ItemProperty -Path $key2 -Name "PauseFeatureUpdates" -Value "0" -Verbose; Write-UILog "  Reset: PauseFeatureUpdates (old: $v)" } else { Write-UILog "  Already 0: PauseFeatureUpdates" } }
        if ($props2 -contains "DeferFeatureUpdatesPeriodInDays") { $v = $val2.GetValue("DeferFeatureUpdatesPeriodInDays"); if ($v -ne "0") { Set-ItemProperty -Path $key2 -Name "DeferFeatureUpdatesPeriodInDays" -Value "0" -Verbose; Write-UILog "  Reset: DeferFeatureUpdatesPeriodInDays (old: $v)" } else { Write-UILog "  Already 0: DeferFeatureUpdatesPeriodInDays" } }
    } else { Write-UILog "  Not found: $key2" }
    $key3 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (Test-Path $key3) {
        $val3 = Get-Item $key3 -EA Ignore; $props3 = $val3.Property
        if ($props3 -contains "AllowDeviceNameInTelemetry") { $v = $val3.GetValue("AllowDeviceNameInTelemetry"); if ($v -ne "1") { Set-ItemProperty -Path $key3 -Name "AllowDeviceNameInTelemetry" -Value "1" -Verbose; Write-UILog "  Fixed: AllowDeviceNameInTelemetry -> 1 (old: $v)" } else { Write-UILog "  Already 1: AllowDeviceNameInTelemetry" } } else { New-ItemProperty -Path $key3 -PropertyType DWORD -Name "AllowDeviceNameInTelemetry" -Value "1" -Verbose; Write-UILog "  Created: AllowDeviceNameInTelemetry = 1" }
        if ($props3 -contains "AllowTelemetry_PolicyManager") { $v = $val3.GetValue("AllowTelemetry_PolicyManager"); if ($v -ne "1") { Set-ItemProperty -Path $key3 -Name "AllowTelemetry_PolicyManager" -Value "1" -Verbose; Write-UILog "  Fixed: AllowTelemetry_PolicyManager -> 1 (old: $v)" } else { Write-UILog "  Already 1: AllowTelemetry_PolicyManager" } } else { New-ItemProperty -Path $key3 -PropertyType DWORD -Name "AllowTelemetry_PolicyManager" -Value "1" -Verbose; Write-UILog "  Created: AllowTelemetry_PolicyManager = 1" }
    } else { Write-UILog "  Not found: $key3" }
    $key4 = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Appraiser\GWX"
    if (Test-Path $key4) { $val4 = Get-Item $key4 -EA Ignore; if ($val4.Property -contains "GStatus") { $v = $val4.GetValue("GStatus"); if ($v -ne "2") { Set-ItemProperty -Path $key4 -Name "GStatus" -Value "2" -Verbose; Write-UILog "  Fixed: GStatus -> 2 (old: $v)" } else { Write-UILog "  Already 2: GStatus" } } else { New-ItemProperty -Path $key4 -PropertyType DWORD -Name "GStatus" -Value "2" -Verbose; Write-UILog "  Created: GStatus = 2" } } else { Write-UILog "  Not found: $key4" }
    Write-UILog "Step 1/10 - Completed"
}

function Invoke-Step2 {
    Write-UILog "Step 2/10 - Stopping Windows Update services..."
    Stop-Service -Name BITS -Force -Verbose -ErrorAction SilentlyContinue
    Stop-Service -Name wuauserv -Force -Verbose -ErrorAction SilentlyContinue
    Stop-Service -Name cryptsvc -Force -Verbose -ErrorAction SilentlyContinue
    Write-UILog "Step 2/10 - Completed (BITS, wuauserv, cryptsvc stopped)"
}

function Invoke-Step3 {
    Write-UILog "Step 3/10 - Clearing QMGR data files..."
    Remove-Item -Path "$env:allusersprofile\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -ErrorAction SilentlyContinue -Verbose
    Write-UILog "Step 3/10 - Completed"
}

function Invoke-Step4 {
    Write-UILog "Step 4/10 - Clearing update cache..."
    Remove-Item -Path "$env:systemroot\SoftwareDistribution" -ErrorAction SilentlyContinue -Recurse -Verbose
    Remove-Item -Path "$env:systemroot\System32\Catroot2" -ErrorAction SilentlyContinue -Recurse -Verbose
    Write-UILog "Step 4/10 - Completed (SoftwareDistribution, Catroot2 deleted)"
}

function Invoke-Step5 {
    Write-UILog "Step 5/10 - Resetting service permissions..."
    Start-Process "sc.exe" -ArgumentList "sdset bits D:(A;CI;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)" -Wait
    Start-Process "sc.exe" -ArgumentList "sdset wuauserv D:(A;;CCLCSWRPLORC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)" -Wait
    Write-UILog "Step 5/10 - Completed"
}

function Invoke-Step6 {
    Write-UILog "Step 6/10 - Re-registering DLLs..."
    Set-Location $env:systemroot\system32
    $dlls = @("atl.dll","urlmon.dll","mshtml.dll","shdocvw.dll","browseui.dll","jscript.dll","vbscript.dll","scrrun.dll","msxml.dll","msxml3.dll","msxml6.dll","actxprxy.dll","softpub.dll","wintrust.dll","dssenh.dll","rsaenh.dll","gpkcsp.dll","sccbase.dll","slbcsp.dll","cryptdlg.dll","oleaut32.dll","ole32.dll","shell32.dll","initpki.dll","wuapi.dll","wuaueng.dll","wuaueng1.dll","wucltui.dll","wups.dll","wups2.dll","wuweb.dll","qmgr.dll","qmgrprxy.dll","wucltux.dll","muweb.dll","wuwebv.dll")
    $dllCount = 0
    foreach ($dll in $dlls) {
        if ($script:ShouldCancel) { Write-UILog "  DLL registration cancelled."; return }
        regsvr32.exe $dll /s; $dllCount++
        if ($dllCount % 10 -eq 0) { Write-UILog "  $dllCount/36 DLLs registered..."; Refresh-UI }
    }
    Write-UILog "Step 6/10 - Completed ($dllCount DLLs registered)"
}

function Invoke-Step7 {
    Write-UILog "Step 7/10 - Resetting Winsock..."
    netsh winsock reset
    Write-UILog "Step 7/10 - Completed"
}

function Invoke-Step8 {
    Write-UILog "Step 8/10 - Starting Windows Update services..."
    Start-Service -Name BITS -Verbose -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -Verbose -ErrorAction SilentlyContinue
    Start-Service -Name cryptsvc -Verbose -ErrorAction SilentlyContinue
    Write-UILog "Step 8/10 - Completed"
}

function Invoke-Step9 {
    Write-UILog "Step 9/10 - Starting update scan (USOClient)..."
    USOClient.exe StartInteractiveScan
    Write-UILog "Step 9/10 - Scan started, waiting 5 minutes..."
    for ($s = 0; $s -lt 300; $s++) {
        if ($script:ShouldCancel) { Write-UILog "  Wait cancelled."; return }
        Start-Sleep -Seconds 1; Refresh-UI
    }
    Write-UILog "Step 9/10 - Wait completed"
}

function Invoke-Step10 {
    Write-UILog "Step 10/10 - Creating diagnostic log with SetupDiag..."
    try {
        $setupDiagUrl = "https://go.microsoft.com/fwlink/?linkid=870142"
        $setupDiagPath = "$script:LogDir\SetupDiag.exe"
        $diagOutput = "$script:LogDir\#Windows Updates - Diagnostics.log"
        $webClient = New-Object System.Net.WebClient
        Write-UILog "  Downloading SetupDiag..."; Refresh-UI
        $webClient.DownloadFile($setupDiagUrl, $setupDiagPath)
        Write-UILog "  Download completed"
        $checkLogs = Test-Path -Path "$script:LogDir\logs*.zip"
        if ($checkLogs) { Remove-Item -Path "$script:LogDir\logs*.zip" -Force -Recurse; Write-UILog "  Old log zips cleaned" }
        Write-UILog "  Running SetupDiag..."; Refresh-UI
        & "$setupDiagPath" /Output:"$diagOutput"
        Write-UILog "  Diagnostic log created: $diagOutput"
    } catch { Write-UILog "  SetupDiag failed: $($_.Exception.Message)" }
    Write-UILog "Step 10/10 - Completed"
}

$script:StepDefs = @(
    @{ Id=1;  Name="Policy Cleanup";        Func={Invoke-Step1}; Desc="Clear Windows Update policies" },
    @{ Id=2;  Name="Stop Services";         Func={Invoke-Step2}; Desc="Stop BITS, wuauserv, cryptsvc services" },
    @{ Id=3;  Name="QMGR Cleanup";          Func={Invoke-Step3}; Desc="Delete corrupted download queue files" },
    @{ Id=4;  Name="Cache Cleanup";         Func={Invoke-Step4}; Desc="Clean SoftwareDistribution and Catroot2 folders" },
    @{ Id=5;  Name="Service Permissions";   Func={Invoke-Step5}; Desc="Reset service security descriptors to default" },
    @{ Id=6;  Name="DLL Registration";      Func={Invoke-Step6}; Desc="Re-register 36 Windows Update DLLs" },
    @{ Id=7;  Name="Winsock Reset";         Func={Invoke-Step7}; Desc="Reset network socket configuration" },
    @{ Id=8;  Name="Start Services";        Func={Invoke-Step8}; Desc="Restart the stopped services" },
    @{ Id=9;  Name="Update Scan";           Func={Invoke-Step9}; Desc="Scan for new updates with USOClient" },
    @{ Id=10; Name="SetupDiag Diagnostics"; Func={Invoke-Step10}; Desc="Create diagnostic report with SetupDiag" }
)

$script:StepChecked = @{}
$script:StepPanels  = @()
$script:StepStates  = @{}

function Draw-RoundedRect {
    param([System.Drawing.Graphics]$g, [System.Drawing.Rectangle]$r, [int]$radius, [System.Drawing.Pen]$pen, [System.Drawing.Brush]$fillBrush)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($r.X, $r.Y, $radius, $radius, 180, 90)
    $path.AddArc($r.Right - $radius, $r.Y, $radius, $radius, 270, 90)
    $path.AddArc($r.Right - $radius, $r.Bottom - $radius, $radius, $radius, 0, 90)
    $path.AddArc($r.X, $r.Bottom - $radius, $radius, $radius, 90, 90)
    $path.CloseFigure()
    if ($fillBrush) { $g.FillPath($fillBrush, $path) }
    $g.DrawPath($pen, $path)
    $path.Dispose()
}

function Redraw-Checkbox {
    param([System.Windows.Forms.Panel]$panel, [int]$idx)
    $panel.Invalidate()
}

function Update-StepUI {
    param([int]$Idx, [string]$Status)
    if ($Idx -lt 0 -or $Idx -ge $script:StepDefs.Count) { return }
    if (-not $script:StepPanels[$Idx]) { return }
    $script:StepStates[$Idx] = $Status
    if ($Status -eq "Done") { $script:StepChecked[$Idx] = $true }
    $script:StepPanels[$Idx].Invalidate()
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Windows Update Remediation Tool"
$form.Size = New-Object System.Drawing.Size(660, 710)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = $C_Bg
$form.Font = New-Object System.Drawing.Font("Inter", 12)
$form.KeyPreview = $true

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(660, 40)
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.BackColor = $C_Bg
$form.Controls.Add($headerPanel)

$lblHeaderIcon = New-Object System.Windows.Forms.Label
$lblHeaderIcon.Text = [char]0x2699
$lblHeaderIcon.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 14)
$lblHeaderIcon.ForeColor = $C_Primary
$lblHeaderIcon.AutoSize = $true
$lblHeaderIcon.Location = New-Object System.Drawing.Point(12, 8)
$headerPanel.Controls.Add($lblHeaderIcon)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Windows Update Remediation Tool"
$lblTitle.Font = New-Object System.Drawing.Font("Inter", 18, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $C_TextPrimary
$lblTitle.AutoSize = $true
$lblTitle.Location = New-Object System.Drawing.Point(38, 6)
$headerPanel.Controls.Add($lblTitle)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true; $txtLog.ReadOnly = $true; $txtLog.ScrollBars = "Vertical"
$txtLog.Size = New-Object System.Drawing.Size(600, 180)
$txtLog.Location = New-Object System.Drawing.Point(20, 50)
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 11)
$txtLog.BackColor = $C_Surface
$txtLog.BorderStyle = "FixedSingle"
$txtLog.ForeColor = $C_TextPrimary
$form.Controls.Add($txtLog)

$grpSteps = New-Object System.Windows.Forms.GroupBox
$grpSteps.Text = " STEPS "
$grpSteps.Size = New-Object System.Drawing.Size(600, 210)
$grpSteps.Location = New-Object System.Drawing.Point(20, 260)
$grpSteps.Font = New-Object System.Drawing.Font("Inter", 10)
$grpSteps.ForeColor = $C_OnSurfVar
$form.Controls.Add($grpSteps)

$btnSelectAll = New-Object System.Windows.Forms.Button
$btnSelectAll.Text = "Select All"
$btnSelectAll.Size = New-Object System.Drawing.Size(85, 20)
$btnSelectAll.Location = New-Object System.Drawing.Point(428, 236)
$btnSelectAll.FlatStyle = "Flat"
$btnSelectAll.BackColor = $C_SurfaceCont
$btnSelectAll.ForeColor = $C_OnSurfVar
$btnSelectAll.Font = New-Object System.Drawing.Font("Inter", 9)
$btnSelectAll.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnSelectAll)

$btnDeselectAll = New-Object System.Windows.Forms.Button
$btnDeselectAll.Text = "Deselect All"
$btnDeselectAll.Size = New-Object System.Drawing.Size(90, 20)
$btnDeselectAll.Location = New-Object System.Drawing.Point(516, 236)
$btnDeselectAll.FlatStyle = "Flat"
$btnDeselectAll.BackColor = $C_SurfaceCont
$btnDeselectAll.ForeColor = $C_OnSurfVar
$btnDeselectAll.Font = New-Object System.Drawing.Font("Inter", 9)
$btnDeselectAll.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnDeselectAll)

for ($i = 0; $i -lt $script:StepDefs.Count; $i++) {
    $col = if ($i -lt 5) { 0 } else { 1 }
    $row = if ($i -lt 5) { $i } else { $i - 5 }
    $xBase = if ($col -eq 0) { 10 } else { 310 }
    $yBase = 25 + ($row * 32)

    $script:StepChecked[$i] = $false
    $script:StepStates[$i] = "Ready"

    $rowPanel = New-Object System.Windows.Forms.Panel
    $rowPanel.Size = New-Object System.Drawing.Size(290, 30)
    $rowPanel.Location = New-Object System.Drawing.Point($xBase, $yBase)
    $rowPanel.BackColor = $C_Bg
    $rowPanel.Tag = $i

    $idx = $i
    $rowPanel.Add_Click({
        param($sender, $e)
        $clickedIdx = $sender.Tag
        if ($script:IsRunning) { return }
        $script:StepChecked[$clickedIdx] = -not $script:StepChecked[$clickedIdx]
        $sender.Invalidate()
    })

    $rowPanel.Add_Paint({
        param($sender, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $g.Clear($C_Bg)

        $sIdx = $sender.Tag
        $state = $script:StepStates[$sIdx]
        $isChecked = $script:StepChecked[$sIdx]

        $cbSize = 18
        $cbX = 2
        $cbY = 5
        $cbRect = New-Object System.Drawing.Rectangle($cbX, $cbY, $cbSize, $cbSize)
        $radius = 4

        $borderColor = $C_Border
        $fillBrush = $null
        $checkColor = $C_Border
        $textColor = $C_OnSurfVar
        $fontStyle = [System.Drawing.FontStyle]::Regular
        $stepBg = $C_Bg

        switch ($state) {
            "Running" {
                $borderColor = $C_Primary
                $fillBrush = $null
                $checkColor = $C_Primary
                $textColor = $C_Primary
                $fontStyle = [System.Drawing.FontStyle]::Bold
                $stepBg = [System.Drawing.Color]::FromArgb(25, $C_Primary)
            }
            "Done" {
                $borderColor = $C_Secondary
                $fillBrush = New-Object System.Drawing.SolidBrush($C_Secondary)
                $checkColor = $C_White
                $textColor = $C_Secondary
                $fontStyle = [System.Drawing.FontStyle]::Bold
                $stepBg = $C_RowHL
            }
            "Error" {
                $borderColor = $C_Error
                $fillBrush = $null
                $checkColor = $C_Error
                $textColor = $C_Error
                $fontStyle = [System.Drawing.FontStyle]::Bold
                $stepBg = [System.Drawing.ColorTranslator]::FromHtml("#FFEBEE")
            }
            default {
                if ($isChecked) {
                    $borderColor = $C_Primary
                    $fillBrush = New-Object System.Drawing.SolidBrush($C_Primary)
                    $checkColor = $C_White
                    $textColor = $C_Primary
                    $fontStyle = [System.Drawing.FontStyle]::Bold
                    $stepBg = [System.Drawing.Color]::FromArgb(25, $C_Primary)
                }
            }
        }

        if ($state -eq "Done" -or $state -eq "Running" -or $state -eq "Error" -or ($state -ne "Waiting" -and $isChecked)) {
            $bgBrush = New-Object System.Drawing.SolidBrush($stepBg)
            $g.FillRectangle($bgBrush, $sender.ClientRectangle)
            $bgBrush.Dispose()
        }

        if ($state -eq "Running") {
            $leftBorderPen = New-Object System.Drawing.Pen($C_Primary, 4)
            $g.DrawLine($leftBorderPen, 0, 0, 0, $sender.Height)
            $leftBorderPen.Dispose()
        }

        $pen = New-Object System.Drawing.Pen($borderColor, 1.5)
        Draw-RoundedRect -g $g -r $cbRect -radius $radius -pen $pen -fillBrush $fillBrush
        $pen.Dispose()
        if ($fillBrush) { $fillBrush.Dispose() }

        if ($state -eq "Done" -or ($isChecked -and $state -ne "Running" -and $state -ne "Error" -and $state -ne "Waiting")) {
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $checkPen = New-Object System.Drawing.Pen($checkColor, 2)
            $g.DrawLine($checkPen, ($cbX + 4), ($cbY + 9), ($cbX + 7), ($cbY + 12))
            $g.DrawLine($checkPen, ($cbX + 7), ($cbY + 12), ($cbX + 13), ($cbY + 5))
            $checkPen.Dispose()
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        }

        $stepName = "$($script:StepDefs[$sIdx].Id). $($script:StepDefs[$sIdx].Name)"
        $labelFont = New-Object System.Drawing.Font("Inter", 10, $fontStyle)
        $labelBrush = New-Object System.Drawing.SolidBrush($textColor)

        $statText = ""
        $statColor = $C_Disabled
        switch ($state) {
            "Running" { $statText = "[* Running]"; $statColor = $C_Primary }
            "Done"    { $statText = "[" + [char]0x2713 + " Completed]"; $statColor = $C_Secondary }
            "Error"   { $statText = "[X Error]"; $statColor = $C_Error }
            default   { if ($isChecked) { $statText = "[Selected]"; $statColor = $C_Primary } else { $statText = "[Waiting]"; $statColor = $C_Disabled } }
        }
        $statFont = New-Object System.Drawing.Font("Inter", 10)

        $nameSize = $g.MeasureString($stepName, $labelFont)
        $statSize = $g.MeasureString($statText, $statFont)
        $statX = [math]::Max(190, ($cbX + $cbSize + 6 + $nameSize.Width + 10))
        $statX = [math]::Min($statX, ($sender.Width - $statSize.Width - 4))

        $g.DrawString($stepName, $labelFont, $labelBrush, ($cbX + $cbSize + 6), 3)
        $labelBrush.Dispose()
        $labelFont.Dispose()

        $statBrush = New-Object System.Drawing.SolidBrush($statColor)
        $g.DrawString($statText, $statFont, $statBrush, $statX, 3)
        $statBrush.Dispose()
        $statFont.Dispose()
    })

    $grpSteps.Controls.Add($rowPanel)
    $script:StepPanels += $rowPanel
}

$lblProgressTitle = New-Object System.Windows.Forms.Label
$lblProgressTitle.Text = "Progress: Step 0/10"
$lblProgressTitle.Size = New-Object System.Drawing.Size(400, 20)
$lblProgressTitle.Location = New-Object System.Drawing.Point(20, 480)
$lblProgressTitle.Font = New-Object System.Drawing.Font("Inter", 12)
$lblProgressTitle.ForeColor = $C_TextPrimary
$form.Controls.Add($lblProgressTitle)

$lblProgressPct = New-Object System.Windows.Forms.Label
$lblProgressPct.Text = "%0"; $lblProgressPct.Size = New-Object System.Drawing.Size(60, 20)
$lblProgressPct.Location = New-Object System.Drawing.Point(560, 480)
$lblProgressPct.Font = New-Object System.Drawing.Font("Inter", 11)
$lblProgressPct.ForeColor = $C_Primary; $lblProgressPct.TextAlign = "MiddleRight"
$form.Controls.Add($lblProgressPct)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Minimum = 0; $progressBar.Maximum = 10; $progressBar.Value = 0
$progressBar.Size = New-Object System.Drawing.Size(600, 20)
$progressBar.Location = New-Object System.Drawing.Point(20, 504)
$progressBar.Style = "Continuous"
$form.Controls.Add($progressBar)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start All"
$btnStart.Size = New-Object System.Drawing.Size(290, 35)
$btnStart.Location = New-Object System.Drawing.Point(20, 534)
$btnStart.BackColor = $C_Secondary
$btnStart.ForeColor = $C_White; $btnStart.FlatStyle = "Flat"
$btnStart.Font = New-Object System.Drawing.Font("Inter", 12)
$btnStart.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnStart)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "Stop"
$btnStop.Size = New-Object System.Drawing.Size(290, 35)
$btnStop.Location = New-Object System.Drawing.Point(320, 534)
$btnStop.BackColor = $C_Error
$btnStop.ForeColor = $C_White; $btnStop.FlatStyle = "Flat"
$btnStop.Font = New-Object System.Drawing.Font("Inter", 12)
$btnStop.Enabled = $false; $btnStop.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnStop)

$btnOpenLog = New-Object System.Windows.Forms.Button
$btnOpenLog.Text = "Open Log File"
$btnOpenLog.Size = New-Object System.Drawing.Size(290, 35)
$btnOpenLog.Location = New-Object System.Drawing.Point(20, 574)
$btnOpenLog.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2196F3")
$btnOpenLog.ForeColor = $C_White; $btnOpenLog.FlatStyle = "Flat"
$btnOpenLog.Font = New-Object System.Drawing.Font("Inter", 12)
$btnOpenLog.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnOpenLog)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Size = New-Object System.Drawing.Size(290, 35)
$btnClose.Location = New-Object System.Drawing.Point(320, 574)
$btnClose.BackColor = $C_SurfaceCont
$btnClose.ForeColor = $C_TextPrimary; $btnClose.FlatStyle = "Flat"
$btnClose.Font = New-Object System.Drawing.Font("Inter", 12)
$btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnClose)

$btnSetupDiag = New-Object System.Windows.Forms.Button
$btnSetupDiag.Text = "Open SetupDiag Log"
$btnSetupDiag.Size = New-Object System.Drawing.Size(600, 35)
$btnSetupDiag.Location = New-Object System.Drawing.Point(20, 614)
$btnSetupDiag.BackColor = $C_SurfaceCont
$btnSetupDiag.ForeColor = $C_TextPrimary; $btnSetupDiag.FlatStyle = "Flat"
$btnSetupDiag.Font = New-Object System.Drawing.Font("Inter", 12)
$btnSetupDiag.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnSetupDiag.Enabled = $false
$form.Controls.Add($btnSetupDiag)

$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusBar.BackColor = $C_SurfaceLow
$statusBar.SizingGrip = $false
$statusBar.Height = 24

$statusLblLeft = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLblLeft.Text = [char]0x25CF + " Ready"
$statusLblLeft.ForeColor = $C_Secondary
$statusLblLeft.Font = New-Object System.Drawing.Font("Inter", 10)
$statusBar.Items.Add($statusLblLeft) | Out-Null

$sep1 = New-Object System.Windows.Forms.ToolStripSeparator
$sep1.Text = "|"; $sep1.ForeColor = $C_Border; $sep1.Font = New-Object System.Drawing.Font("Inter", 10)
$statusBar.Items.Add($sep1) | Out-Null

$statusLblAdmin = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLblAdmin.Text = "Admin Mode: Active"
$statusLblAdmin.ForeColor = $C_OnSurfVar
$statusLblAdmin.Font = New-Object System.Drawing.Font("Inter", 10)
$statusBar.Items.Add($statusLblAdmin) | Out-Null

$stretch = New-Object System.Windows.Forms.ToolStripStatusLabel
$stretch.Spring = $true; $stretch.Text = ""
$statusBar.Items.Add($stretch) | Out-Null

$statusLblRight = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLblRight.Text = $script:LogFile
$statusLblRight.ForeColor = $C_OnSurfVar
$statusLblRight.Font = New-Object System.Drawing.Font("Inter", 10)
$statusBar.Items.Add($statusLblRight) | Out-Null
$form.Controls.Add($statusBar)

function Set-UIState {
    param([string]$State)
    switch ($State) {
        "Ready" {
            $btnStart.Enabled = $true;  $btnStop.Enabled = $false
            $btnStart.BackColor = $C_Secondary; $btnStop.BackColor = $C_Disabled
            $statusLblLeft.Text = [char]0x25CF + " Ready"
            $statusLblLeft.ForeColor = $C_Secondary
        }
        "Running" {
            $btnStart.Enabled = $false; $btnStop.Enabled = $true
            $btnStart.BackColor = $C_Disabled; $btnStop.BackColor = $C_Error
            $btnStop.ForeColor = $C_White
            $statusLblLeft.Text = [char]0x25CF + " Running..."
            $statusLblLeft.ForeColor = $C_Primary
        }
        "Done" {
            $btnStart.Enabled = $true;  $btnStop.Enabled = $false
            $btnStart.BackColor = $C_Secondary; $btnStop.BackColor = $C_Disabled
            $statusLblLeft.Text = [char]0x25CF + " Completed"
            $statusLblLeft.ForeColor = $C_Secondary
        }
        "Stopped" {
            $btnStart.Enabled = $true;  $btnStop.Enabled = $false
            $btnStart.BackColor = $C_Secondary; $btnStop.BackColor = $C_Disabled
            $statusLblLeft.Text = [char]0x25CF + " Stopped"
            $statusLblLeft.ForeColor = $C_Warning
        }
    }
}

function Show-CompletionDialog {
    param([int]$CompletedSteps, [int]$ErrorCount, [string]$Duration, [string]$LogPath)

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Process Completed"
    $dlg.ClientSize = New-Object System.Drawing.Size(560, 330)
    $dlg.StartPosition = "CenterParent"
    $dlg.FormBorderStyle = "FixedSingle"
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
    $dlg.KeyPreview = $true

    $dlgHeader = New-Object System.Windows.Forms.Panel
    $dlgHeader.Size = New-Object System.Drawing.Size(560, 48)
    $dlgHeader.Location = New-Object System.Drawing.Point(0, 0)
    $dlgHeader.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#f9f9f9")
    $dlg.Controls.Add($dlgHeader)

    $headerLine = New-Object System.Windows.Forms.Label
    $headerLine.Size = New-Object System.Drawing.Size(560, 1)
    $headerLine.Location = New-Object System.Drawing.Point(0, 47)
    $headerLine.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#D1D1D1")
    $dlgHeader.Controls.Add($headerLine)

    $dlgHeaderIcon = New-Object System.Windows.Forms.Label
    $dlgHeaderIcon.Text = [char]0x2714
    $dlgHeaderIcon.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 14)
    $dlgHeaderIcon.ForeColor = $C_Secondary
    $dlgHeaderIcon.AutoSize = $true
    $dlgHeaderIcon.Location = New-Object System.Drawing.Point(20, 12)
    $dlgHeader.Controls.Add($dlgHeaderIcon)

    $dlgHeaderTitle = New-Object System.Windows.Forms.Label
    $dlgHeaderTitle.Text = "Process Completed"
    $dlgHeaderTitle.Font = New-Object System.Drawing.Font("Inter", 16, [System.Drawing.FontStyle]::Bold)
    $dlgHeaderTitle.ForeColor = $C_TextPrimary
    $dlgHeaderTitle.AutoSize = $true
    $dlgHeaderTitle.Location = New-Object System.Drawing.Point(42, 12)
    $dlgHeader.Controls.Add($dlgHeaderTitle)

    $dlgContent = New-Object System.Windows.Forms.Panel
    $dlgContent.Size = New-Object System.Drawing.Size(520, 200)
    $dlgContent.Location = New-Object System.Drawing.Point(20, 55)
    $dlgContent.BackColor = [System.Drawing.Color]::FromArgb(255, 240, 253, 244)
    $dlg.Controls.Add($dlgContent)

    $dlgSuccessTitle = New-Object System.Windows.Forms.Label
    $dlgSuccessTitle.Text = "All steps completed successfully!"
    $dlgSuccessTitle.Font = New-Object System.Drawing.Font("Inter", 12, [System.Drawing.FontStyle]::Bold)
    $dlgSuccessTitle.ForeColor = $C_Secondary
    $dlgSuccessTitle.AutoSize = $true
    $dlgSuccessTitle.Location = New-Object System.Drawing.Point(10, 8)
    $dlgContent.Controls.Add($dlgSuccessTitle)

    $dlgSuccessDesc = New-Object System.Windows.Forms.Label
    $dlgSuccessDesc.Text = "System optimization and update repair operations completed without errors."
    $dlgSuccessDesc.Font = New-Object System.Drawing.Font("Inter", 10)
    $dlgSuccessDesc.ForeColor = $C_OnSurfVar
    $dlgSuccessDesc.Size = New-Object System.Drawing.Size(500, 20)
    $dlgSuccessDesc.Location = New-Object System.Drawing.Point(10, 32)
    $dlgContent.Controls.Add($dlgSuccessDesc)

    $infoPanel = New-Object System.Windows.Forms.Panel
    $infoPanel.Size = New-Object System.Drawing.Size(500, 80)
    $infoPanel.Location = New-Object System.Drawing.Point(10, 55)
    $infoPanel.BackColor = [System.Drawing.Color]::FromArgb(153, 255, 255, 255)
    $infoPanel.BorderStyle = "FixedSingle"
    $dlgContent.Controls.Add($infoPanel)

    $lblStepsInfo = New-Object System.Windows.Forms.Label
    $lblStepsInfo.Text = [char]0x2714 + "  $CompletedSteps/10 steps completed successfully"
    $lblStepsInfo.Font = New-Object System.Drawing.Font("Inter", 10)
    $lblStepsInfo.ForeColor = $C_TextPrimary
    $lblStepsInfo.AutoSize = $true
    $lblStepsInfo.Location = New-Object System.Drawing.Point(12, 10)
    $infoPanel.Controls.Add($lblStepsInfo)

    $lblTimeInfo = New-Object System.Windows.Forms.Label
    $lblTimeInfo.Text = [char]0x25F7 + "  Total time: $Duration"
    $lblTimeInfo.Font = New-Object System.Drawing.Font("Inter", 10)
    $lblTimeInfo.ForeColor = $C_Primary
    $lblTimeInfo.AutoSize = $true
    $lblTimeInfo.Location = New-Object System.Drawing.Point(12, 34)
    $infoPanel.Controls.Add($lblTimeInfo)

    $lblLogInfo = New-Object System.Windows.Forms.Label
    $lblLogInfo.Text = $LogPath
    $lblLogInfo.Font = New-Object System.Drawing.Font("Consolas", 9)
    $lblLogInfo.ForeColor = $C_OnSurfVar
    $lblLogInfo.Size = New-Object System.Drawing.Size(470, 18)
    $lblLogInfo.Location = New-Object System.Drawing.Point(12, 58)
    $lblLogInfo.AutoEllipsis = $true
    $infoPanel.Controls.Add($lblLogInfo)

    $warnPanel = New-Object System.Windows.Forms.Panel
    $warnPanel.Size = New-Object System.Drawing.Size(500, 35)
    $warnPanel.Location = New-Object System.Drawing.Point(10, 145)
    $warnPanel.BackColor = [System.Drawing.Color]::FromArgb(25, $C_Warning)
    $dlgContent.Controls.Add($warnPanel)

    $warnBorder = New-Object System.Windows.Forms.Label
    $warnBorder.Size = New-Object System.Drawing.Size(4, 35)
    $warnBorder.Location = New-Object System.Drawing.Point(0, 0)
    $warnBorder.BackColor = $C_Warning
    $warnPanel.Controls.Add($warnBorder)

    $warnIcon = New-Object System.Windows.Forms.Label
    $warnIcon.Text = [char]0x2139
    $warnIcon.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 12)
    $warnIcon.ForeColor = $C_Warning
    $warnIcon.AutoSize = $true
    $warnIcon.Location = New-Object System.Drawing.Point(12, 8)
    $warnPanel.Controls.Add($warnIcon)

    $warnText = New-Object System.Windows.Forms.Label
    $warnText.Text = "A system restart is recommended."
    $warnText.Font = New-Object System.Drawing.Font("Inter", 10)
    $warnText.ForeColor = $C_TextPrimary
    $warnText.AutoSize = $true
    $warnText.Location = New-Object System.Drawing.Point(34, 9)
    $warnPanel.Controls.Add($warnText)

    $dlgFooter = New-Object System.Windows.Forms.Panel
    $dlgFooter.Size = New-Object System.Drawing.Size(560, 55)
    $dlgFooter.Location = New-Object System.Drawing.Point(0, 265)
    $dlgFooter.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#f3f3f3")
    $dlg.Controls.Add($dlgFooter)

    $footerLine = New-Object System.Windows.Forms.Label
    $footerLine.Size = New-Object System.Drawing.Size(560, 1)
    $footerLine.Location = New-Object System.Drawing.Point(0, 0)
    $footerLine.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#D1D1D1")
    $dlgFooter.Controls.Add($footerLine)

    $btnDlgLog = New-Object System.Windows.Forms.Button
    $btnDlgLog.Text = "Open Log"
    $btnDlgLog.Size = New-Object System.Drawing.Size(110, 38)
    $btnDlgLog.Location = New-Object System.Drawing.Point(80, 10)
    $btnDlgLog.BackColor = $C_PrimaryCont
    $btnDlgLog.ForeColor = $C_White
    $btnDlgLog.FlatStyle = "Flat"
    $btnDlgLog.Font = New-Object System.Drawing.Font("Inter", 10, [System.Drawing.FontStyle]::Bold)
    $btnDlgLog.Cursor = [System.Windows.Forms.Cursors]::Hand
    $dlgFooter.Controls.Add($btnDlgLog)

    $btnDlgSetupDiag = New-Object System.Windows.Forms.Button
    $btnDlgSetupDiag.Text = "SetupDiag Log"
    $btnDlgSetupDiag.Size = New-Object System.Drawing.Size(120, 38)
    $btnDlgSetupDiag.Location = New-Object System.Drawing.Point(200, 10)
    $btnDlgSetupDiag.BackColor = $C_PrimaryCont
    $btnDlgSetupDiag.ForeColor = $C_White
    $btnDlgSetupDiag.FlatStyle = "Flat"
    $btnDlgSetupDiag.Font = New-Object System.Drawing.Font("Inter", 10, [System.Drawing.FontStyle]::Bold)
    $btnDlgSetupDiag.Cursor = [System.Windows.Forms.Cursors]::Hand
    $dlgFooter.Controls.Add($btnDlgSetupDiag)

    $btnDlgRestart = New-Object System.Windows.Forms.Button
    $btnDlgRestart.Text = "Restart"
    $btnDlgRestart.Size = New-Object System.Drawing.Size(110, 38)
    $btnDlgRestart.Location = New-Object System.Drawing.Point(330, 10)
    $btnDlgRestart.BackColor = $C_Warning
    $btnDlgRestart.ForeColor = $C_White
    $btnDlgRestart.FlatStyle = "Flat"
    $btnDlgRestart.Font = New-Object System.Drawing.Font("Inter", 10, [System.Drawing.FontStyle]::Bold)
    $btnDlgRestart.Cursor = [System.Windows.Forms.Cursors]::Hand
    $dlgFooter.Controls.Add($btnDlgRestart)

    $btnDlgClose = New-Object System.Windows.Forms.Button
    $btnDlgClose.Text = "Close"
    $btnDlgClose.Size = New-Object System.Drawing.Size(70, 38)
    $btnDlgClose.Location = New-Object System.Drawing.Point(450, 10)
    $btnDlgClose.BackColor = $C_Disabled
    $btnDlgClose.ForeColor = $C_White
    $btnDlgClose.FlatStyle = "Flat"
    $btnDlgClose.Font = New-Object System.Drawing.Font("Inter", 10, [System.Drawing.FontStyle]::Bold)
    $btnDlgClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $dlgFooter.Controls.Add($btnDlgClose)

    $btnDlgLog.Add_Click({
        if (Test-Path $LogPath) { Start-Process notepad.exe $LogPath }
        else { [System.Windows.Forms.MessageBox]::Show("Log file not found.`n$LogPath", "Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) }
    })

    $btnDlgSetupDiag.Add_Click({
        $diagLog = "$script:LogDir\#Windows Updates - Diagnostics.log"
        if (Test-Path $diagLog) { Start-Process notepad.exe $diagLog }
        else { [System.Windows.Forms.MessageBox]::Show("SetupDiag log not found.`n$diagLog", "Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) }
    })

    $btnDlgRestart.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show("The system will restart now.`nSave all open work before continuing.", "Restart System", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($r -eq [System.Windows.Forms.DialogResult]::Yes) {
            $dlg.Close()
            Start-Process shutdown.exe -ArgumentList "/r /t 5 /c `"System restart for Windows Update remediation`""
        }
    })

    $btnDlgClose.Add_Click({ $dlg.Close() })

    $dlg.Add_KeyDown({
        param($s, $e)
        if ($e.KeyCode -eq "Escape") { $dlg.Close(); $e.Handled = $true }
        elseif ($e.KeyCode -eq "Enter") { $dlg.Close(); $e.Handled = $true }
    })

    [void]$dlg.ShowDialog()
    $dlg.Dispose()
}

function Invoke-AllSteps {
    $script:StartTime = Get-Date
    $script:ErrorCount = 0
    $script:ShouldCancel = $false
    $script:IsRunning = $true
    $progressBar.Value = 0
    $lblProgressTitle.Text = "Progress: Step 0/10"
    $lblProgressPct.Text = "%0"

    for ($i = 0; $i -lt $script:StepDefs.Count; $i++) {
        if ($script:StepChecked[$i]) { Update-StepUI -Idx $i -Status "Waiting" }
    }
    Set-UIState -State "Running"
    Write-UILog "=== Windows Update Remediation Started ==="
    Refresh-UI

    $completed = 0
    for ($i = 0; $i -lt $script:StepDefs.Count; $i++) {
        if ($script:ShouldCancel) { Write-UILog "=== Process cancelled by user - Step $($i)/10 ==="; break }
        if (-not $script:StepChecked[$i]) { continue }

        Update-StepUI -Idx $i -Status "Running"
        $progressBar.Value = $completed
        $lblProgressTitle.Text = "Progress: Step $completed/10"
        $lblProgressPct.Text = "%$([math]::Round(($completed/10)*100))"
        Refresh-UI

        try { & $script:StepDefs[$i].Func; Update-StepUI -Idx $i -Status "Done"; $completed++
            if ($i -eq 9) { $btnSetupDiag.Enabled = $true }
        }
        catch { $script:ErrorCount++; Update-StepUI -Idx $i -Status "Error"; Write-UILog "  ERROR: $($_.Exception.Message)" }

        $progressBar.Value = $completed
        $lblProgressTitle.Text = "Progress: Step $completed/10"
        $lblProgressPct.Text = "%$([math]::Round(($completed/10)*100))"
        Refresh-UI
    }

    $elapsed = (Get-Date) - $script:StartTime
    $min = $elapsed.Minutes; $sec = $elapsed.Seconds
    $script:IsRunning = $false

    if ($script:ShouldCancel) {
        Write-UILog "Total time: $min min $sec sec"
        Set-UIState -State "Stopped"
    } else {
        if ($script:ErrorCount -gt 0) { Write-UILog "=== Process completed ($script:ErrorCount errors) ===" }
        else { Write-UILog "=== Windows Update Remediation Completed ===" }
        Write-UILog "Total time: $min min $sec sec"
        Set-UIState -State "Done"
        Show-CompletionDialog -CompletedSteps $completed -ErrorCount $script:ErrorCount -Duration "$min min $sec sec" -LogPath $script:LogFile
    }
}

function Invoke-SingleStep {
    param([int]$StepIndex)
    $step = $script:StepDefs[$StepIndex]
    $script:StartTime = Get-Date; $script:ErrorCount = 0; $script:ShouldCancel = $false; $script:IsRunning = $true
    Set-UIState -State "Running"; Update-StepUI -Idx $StepIndex -Status "Running"
    Write-UILog "=== Running Single Step: $($step.Id). $($step.Name) ==="; Refresh-UI
    try { & $step.Func; Update-StepUI -Idx $StepIndex -Status "Done"
        if ($StepIndex -eq 9) { $btnSetupDiag.Enabled = $true }
    }
    catch { $script:ErrorCount++; Update-StepUI -Idx $StepIndex -Status "Error"; Write-UILog "  ERROR: $($_.Exception.Message)" }
    $elapsed = (Get-Date) - $script:StartTime; $min = $elapsed.Minutes; $sec = $elapsed.Seconds
    $script:IsRunning = $false; Set-UIState -State "Done"
    if ($script:ErrorCount -gt 0) { Write-UILog "=== Step completed with errors ===" }
    else { Write-UILog "=== Step completed successfully (time: $min min $sec sec) ===" }
}

$btnSelectAll.Add_Click({
    if ($script:IsRunning) { return }
    for ($i = 0; $i -lt $script:StepDefs.Count; $i++) { $script:StepChecked[$i] = $true }
    for ($i = 0; $i -lt $script:StepDefs.Count; $i++) { $script:StepPanels[$i].Invalidate() }
})

$btnDeselectAll.Add_Click({
    if ($script:IsRunning) { return }
    for ($i = 0; $i -lt $script:StepDefs.Count; $i++) { $script:StepChecked[$i] = $false }
    for ($i = 0; $i -lt $script:StepDefs.Count; $i++) { $script:StepPanels[$i].Invalidate() }
})

$btnStart.Add_Click({
    $sel = ($script:StepChecked.Values | Where-Object { $_ }).Count
    if ($sel -eq 0) { [System.Windows.Forms.MessageBox]::Show("Please select at least one step to run.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning); return }
    $est = [math]::Max(1, [math]::Ceiling($sel * 0.8))
    $r = [System.Windows.Forms.MessageBox]::Show("Selected steps will be run sequentially.`n`nTotal steps: $sel`nEstimated time: ~$est minutes.`n`nDo you want to continue?", "Confirm Operation", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($r -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    Invoke-AllSteps
})

$btnStop.Add_Click({
    $r = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to stop?`n`nThe process will stop after the current step completes.", "Stop Operation", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($r -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $script:ShouldCancel = $true
})

$btnOpenLog.Add_Click({
    if (Test-Path $script:LogFile) { Start-Process notepad.exe $script:LogFile }
    else { [System.Windows.Forms.MessageBox]::Show("Log file has not been created yet.`n$script:LogFile", "Log File Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) }
})

$btnSetupDiag.Add_Click({
    $diagLog = "$script:LogDir\#Windows Updates - Diagnostics.log"
    if (Test-Path $diagLog) { Start-Process notepad.exe $diagLog }
    else { [System.Windows.Forms.MessageBox]::Show("SetupDiag log has not been created yet.`n$diagLog", "SetupDiag Log Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) }
})

$btnClose.Add_Click({
    if ($script:IsRunning) {
        $r = [System.Windows.Forms.MessageBox]::Show("Process is still running!`n`nClosing the application will interrupt ongoing operations.`nAre you sure you want to close?", "Close Application", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($r -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        $script:ShouldCancel = $true
    }
    $form.Close()
})

$form.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq "F5" -and $btnStart.Enabled) { $btnStart.PerformClick(); $e.Handled = $true }
    elseif ($e.KeyCode -eq "Escape") {
        if ($script:IsRunning -and $btnStop.Enabled) { $btnStop.PerformClick() } else { $btnClose.PerformClick() }
        $e.Handled = $true
    }
    elseif ($e.Control -and $e.KeyCode -eq "L") { $btnOpenLog.PerformClick(); $e.Handled = $true }
})

$form.Add_FormClosing({
    param($s, $e)
    if ($script:IsRunning) {
        $r = [System.Windows.Forms.MessageBox]::Show("Process is still running. Are you sure you want to close?", "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($r -ne [System.Windows.Forms.DialogResult]::Yes) { $e.Cancel = $true; return }
        $script:ShouldCancel = $true
    }
})

$tt = New-Object System.Windows.Forms.ToolTip
$tt.SetToolTip($btnStart, "Run selected steps sequentially (F5)")
$tt.SetToolTip($btnStop, "Stop the running process (Esc)")
$tt.SetToolTip($btnOpenLog, "Open log file in Notepad (Ctrl+L)")
$tt.SetToolTip($btnClose, "Close application (Esc)")
$tt.SetToolTip($btnSetupDiag, "Open SetupDiag diagnostic log in Notepad")
for ($i = 0; $i -lt $script:StepDefs.Count; $i++) { $tt.SetToolTip($script:StepPanels[$i], $script:StepDefs[$i].Desc) }

Write-UILog "Windows Update Remediation Tool started."
Write-UILog "Admin mode: Active"
Write-UILog "Log file: $script:LogFile"
Write-UILog "---"

[void]$form.ShowDialog()
$form.Dispose()

# ============================================================================
#  AUTHOR INFO
# ============================================================================
#  Name:       Mert Ozsoy
#  Website:    https://mertozsoy.com/
#  LinkedIn:   https://www.linkedin.com/in/mertozsoy365/
#  YouTube:    https://www.youtube.com/@mertozsoy365
#  GitHub:     https://github.com/mertozsoy
# ============================================================================
