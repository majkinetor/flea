. "$PSScriptRoot\..\inc\flea.ps1"

$urls = @"
www.google.com
www.yahoo.com
www.bing.com
"@

function url_monitor($urls) {
    . "$PSScriptRoot\rand.ps1"
    @{
        'metric1' = rand
        'metric2' = rand
     }
}

flea @{
    root       = $PSScriptRoot;
    freq       = 5;
    backends   = @(
        #,(file "out.txt")
        ,(console yellow red)
    );
    debug      = 1;
    monitors   = @(
            , ("cpu_load",      -1, "cpu_load",  3)
            , ("url_monitor",    1, ".url_monitor", $urls)
    )
}


