. "$PSScriptRoot\..\inc\flea.ps1"

flea @{
    freq       = 10;
    backends   = @(
        ,(file "out.txt")
        ,(console yellow red)
    );
    debug      = 1;
    monitors   = @(
            , ("cpu_load", -1,     "cpu_load",  9)
            , ("ram_free", 6,      "ram_free")
            , ("disk_c",   '*/1m', "disk_free", "c:")
    )
}
