. "$PSScriptRoot\..\inc\flea.ps1"

function url_monitor($url, $prefix) {
    . .\rand.ps1

    $request = New-Object System.Net.WebClient
    $request.UseDefaultCredentials = $true
    $start = Get-Date
    $pageRequest = $Request.DownloadString($url)
    $timeTaken = ((Get-Date) - $Start).TotalMilliseconds
    $request.Dispose()
    @{
        "$($prefix).time"   = [int]$timeTaken
        "$($prefix).length" = $pageRequest.Length
        "$($prefix).random" = rand
     }
}

flea @{
    freq       = 10;
    backends   = @(
        ,(file "out.txt")
        ,(console yellow red)
    );
    debug      = 1;
    monitors   = @(
            , ("google",   1,  ".url_monitor", 'http://www.google.com', 'google')
            , ("yahoo",    3,  ".url_monitor", 'http://www.yahoo.com',  'yahoo')
            , ("bing",     5,  ".url_monitor", 'http://www.bing.com',   'bing')
    )
}


