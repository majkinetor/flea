# Requires Powershell 3.0 ++

. "$PSScriptRoot\Invoke-SqlCmd.ps1"

function disk_free($disk){
    $s = gwmi Win32_LogicalDisk | ? DeviceID -eq $disk
    $r = "{0:N2}" -f ($s.FreeSpace*100/ $s.Size)
    $r.Replace(',', '.')
}

function ram_free()  {
    $s = gwmi Win32_OperatingSystem
    $r = "{0:N2}" -f ($s.FreePhysicalMemory*100 / $s.TotalVisibleMemorySize)
    $r.Replace(',', '.')
}

function cpu_load($SampleInterval=1) {
    $s = Get-Counter -Counter "\Processor(_total)\% Processor Time" -SampleInterval $SampleInterval
    [int]$s.CounterSamples.CookedValue
}

function service_running($ServiceName) {
    (Get-Service $ServiceName) -eq "Running"
}

function sql_count([hashtable]$db, [string]$TableName, [string]$Where)
{
    $query =  "select COUNT(*) as total from $TableName"
    if ($Where) { $query += "`nwhere $Where" }
    $s = Invoke-SqlCmd $db.server $db.database $query
    $s.total
}

function process_count() {
    (gps).length
}
