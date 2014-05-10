. "$PSScriptRoot\common_metrics.ps1"
. "$PSScriptRoot\backends.ps1"

$action_m1 = { param ([System.Object]$sender, [System.Timers.ElapsedEventArgs]$e)

    $cfg = $event.MessageData
    if (!$cfg) {$cfg = $sender} #When activated via "create-timer -Invoke and not as event"
    Invoke-Expression $cfg._.include_funcs

    $i++;
    foreach ($m in $cfg._.m1)
    {
        if ($i % $m[1] ) { continue }

        $msg, $c = job_ctrl $m[0] ($m[1] -lt 0)
        out "[$i] $($msg): $($m[0])"
        if ($c) {continue}

        exec $m $cfg
     }
}


$action_m2 = { param ([System.Object]$sender, [System.Timers.ElapsedEventArgs]$e)
    $data = $event.MessageData
    if (!$data) {$data = $sender}
    Invoke-Expression $data.cfg._.include_funcs

    if ($data.wait) { $data.timer.Stop(); $data.timer.Interval = $data.freq; $data.timer.Start(); $data.wait = $false; }

    $data.i++
    $m, $cfg, $i = $data['m', 'cfg', 'i']

    $msg, $c = job_ctrl $m[0] ($data.freq -lt 0)
    out "[$i] $($msg): $($m[0])"
    if ($c) { return }

    exec $m $cfg
}

function job_ctrl($jobName, $restart) {

    $c = $false
    $job = Get-Job -Name $jobName
    if ($job) {
        if ($restart) {
            $msg = 'Restarted'
            Remove-Job $job -force }
        else {
            $msg = 'Still running';
            $c=$true
        }
    } else{ $msg = 'Starting' }
    $msg, $c
}

function exec($m, $Data)
{
    # create background job to run the function
    $s  = [scriptblock]::Create('& $args[0] $args[1] $args[2] $args[3] $args[4] $args[5]')
    $mi = @"
. $($Data._.PSScriptRoot)\common_metrics.ps1
$($Data._.include_funcs)
"@

    if ($Data.init_script)  { $mi += ". $Data.init_script;" }
    $si = [scriptblock]::Create($mi)
    $job = Start-Job -Name $m[0] -Init $si -Script $s -ArgumentList $m[2..10]
    if (!$job) {out "ERR: Job creation failed - $($m[0])"}

    # notify when job changes state
    Register-ObjectEvent $job StateChanged -MessageData $Data -Action {
        $cfg = $event.MessageData
        $job = $sender
        #Invoke-Expression $cfg._.include_funcs

        switch ($job.State)
        {
            'Failed'    { out  "ERR: '$($job.Name)' failed - $($job.ChildJobs[0].JobStateInfo.Reason.Message)" }
            'Completed' {
                $r = Receive-Job -Id  $job.id
                # send to backend
                $cfg.backends | % {
                    $s = $_
                    try { $_.Send($job.Name, $r) }
                    catch {
                        out "ERR: Backend '$s' - $_"
                    }
                }
            }
            default     { return }
        }

        Remove-Job $job.Id
        $eventSubscriber | Unregister-Event
        $eventSubscriber.Action | Remove-Job

    } | Out-Null
}

function create_timer( [int]$Freq, [scriptblock]$Action, $Data, [string]$SourceIdentifier=$null, [switch]$Start, [switch]$Invoke ) {
    $timer = New-Object System.Timers.Timer -ArgumentList $Freq

    $args = @{ InputObject = $timer; EventName='Elapsed'; Action=$Action; MessageData=$Data }
    if ($SourceIdentifier) { $args.SourceIdentifier = $SourceIdentifier }
    Register-ObjectEvent @args
    if ($Start)  { $timer.Start()        }
    if ($Invoke) { $Action.Invoke($Data) }
    $timer
}

function prepare([hashtable]$cfg)
{
    # Keep internal data in the _ hash
    $cfg._ = @{PSScriptRoot  = $PSScriptRoot;}
    $inc = @()

    $cfg._.m1 = @(); $cfg._.m2 = @() 
    $cfg.monitors | % {
       if ($_[2].StartsWith('.')) {
            $_[2] = $_[2].SubString(1)
           $inc += $_[2]
       }

       if ($_[1].GetType() -eq [string]) { $cfg._.m2 +=  ,$_  }
       else { $cfg._.m1 += ,$_ }
    }

    # Prepare function imports
    if ($cfg.debug) { $out = 'out1' } else { $out = 'out0' }
    $out_str = func_tostr $out 'script:out'
    Invoke-Expression $out_str

    $inc =  @('out', 'exec', 'job_ctrl') + $inc
    $inc | % { $finc += func_tostr $_ $null $cfg.root }
    $cfg._.include_funcs = $finc;
}

function flea([hashtable]$cfg)
{
    prepare $cfg

    out "START" -SpaceAfter

    # create timers
    if ($cfg._.m1.length -gt 0) {
        create_timer ($cfg.freq*1000) $action_m1 $cfg -Start -Invoke | Out-Null
    }

    $now = get-date
    write-host $x
    $cfg._.m2 | % {
        $m = $_
        $t = calculate_next_time $_[1]
        $freq = $t.freq * 1000
        $args=@{ Freq = [math]::abs($freq); Action = $action_m2; Data=@{cfg=$cfg; m=$m; freq=$freq; timer=$null; }; Start=$true; Invoke=$false;  }
        $ms = ($t.start-$now).TotalMilliseconds
        if ($ms -lt 0){ $args.Invoke = $true }
        else { $args.Freq = $ms; $args.data.wait = $true }
        $args.data.timer = (create_timer @args)[1]
    }

    # Loop
    [console]::TreatControlCAsInput = $true
    while(1) {
        # Check if ctrl+C was pressed and quit if so.
        if ([console]::KeyAvailable) {
            $key = [system.console]::readkey($true)
            if (($key.modifiers -band [consolemodifiers]"control") -and ($key.key -eq "C")) {
                #$timer.Stop()
                #Unregister-Event -SourceIdentifier Timer
                gjb | rjb -f
                break
            }
        }
        sleep -m 100
    }
}

# Desc: <hour|*>[:min|*]/[-]freq[h|m]
function calculate_next_time([string]$Desc)
{
    $dt, $fq = $Desc.split('/')
    $fs = $fq.Substring(0, $fq.length-1)
    $f = switch ($fq[-1]) { 'h' {3600*$fs}; 'm' {60*$fs}; 'd' {86400$fs}; default { $fq } }

    $now = get-date
    $now_h = [int]$now.ToString("HH"); $now_m = [int]$now.ToString("mm")
    $hour, $min = $dt.split(':')

    if ($hour -eq '*') { $hour = $now_h }
    if (($min -eq '*') -or ($min -eq $null)) { if ($now_h -eq $hour){ $min = $now_m } else {$min = 0} }
    elseif ($min -le $now_m) { $hour=([int]$hour)+1; }
    if ($hour -eq 24) {$hour = 0}
    $time = [datetime]"$($hour):$($min)"

    @{start=$time; freq=[int]$f}
}

function out0() {}
function out1($msg, [switch]$SpaceBefore, [switch]$SpaceAfter) {
    $m = [string]::Empty
    if ($SpaceBefore) { $m +="`n" }
    if ($msg) { $m += "$(get-date -f 'yy-MM-dd HH:mm:ss')    $msg" }
    if ($SpaceAfter)  { $m +="`n" }

    $m  | Write-Host
}

function func_tostr($Func, $ReplaceName=$null, $root=$null) {
    $f = gi Function:\$Func
    $name = $f.Name
    if ($ReplaceName -ne $null) { $name = $ReplaceName }
    $x = "function $($name) {$($f.definition.Replace('$PSScriptRoot', $root))}`n"
    $x
}


# TODO - Scheduled func def 
#{
    #name     = '15h';
    #trigger  = '15/1h-18 22:10/30m-01:30';

    #function = "ram_free";
    #args     = 1, 'mislim', (gps);
    #include  = "my include";

    #backends  = $statsd, $file;
#}
