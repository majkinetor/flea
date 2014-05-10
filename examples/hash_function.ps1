. "$PSScriptRoot\..\inc\flea.ps1"

function url_monitor($url, $prefix) {
    $request = New-Object System.Net.WebClient
    $request.UseDefaultCredentials = $true
    $start = Get-Date
    $pageRequest = $Request.DownloadString($url)
    $timeTaken = ((Get-Date) - $Start).TotalMilliseconds
    $request.Dispose()
    @{
        "$($prefix).time"   = $timeTaken
        "$($prefix).length" = $pageRequest.Length
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
            , ("cpu_load", -1, "cpu_load",     3)
            , ("google",   1,  ".url_monitor", 'http://www.google.com', 'google')
            , ("yahoo",    1,  ".url_monitor", 'http://www.yahoo.com',  'yahoo')
            , ("bing",     1,  ".url_monitor", 'http://www.bing.com',   'bing')
    )
}


