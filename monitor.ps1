. "$PSScriptRoot\inc\flea.ps1"

$db         = @{server='pssrino.mfin.trezor.rs'; database='DBRINO'}
$all_monitors = @(
    , ('*',       "cpu_load",              1,         "cpu_load",  9.5)
    , ('*',       "ram_free",              6,         "ram_free")
    , ('*',       "disk_c",                6,         "disk_free", "c:")
    , ('PSSRINO', "count.obaveze_total",   "*:00/1h", "sql_count", $db, 'tNovcanaObaveza')
    , ('PSSRINO', "count.izmirenja_total", "*:00/1h", "sql_count", $db, 'tIzmirenje')
    , ('PSSRINO', "count.obaveze_hour",    "*:00/1h", "sql_count", $db, 'tNovcanaObaveza', 'DATEDIFF(hour, DatumUnosa, GETDATE()) <= 1')
    , ('PSSRINO', "count.izmirenja_hour",  "*:00/1h", "sql_count", $db, 'tNovcanaObaveza', 'DATEDIFF(hour, DatumUnosa, GETDATE()) <= 1')
)

$server   = $Env:ComputerName
$monitors = @()
$all_monitors | ? { ($_[0] -eq $server) -or ($_[0] -eq '*') } | % { $monitors += ,$_[1..($_.length-1)] }
flea @{
    freq     = 10;
    backends = @(
        ,(statsd "10.34.101.34:8125" "rino.servers.$server")
        #,(file)
        #,(console yellow red)
    );
    debug    = 0;
    monitors = $monitors;
}
