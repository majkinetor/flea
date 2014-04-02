# Args: server:port, namespace
function statsd() {
    New-Module -AsCustomObject -ArgumentList $args -ScriptBlock {
        . "$PSScriptRoot\Send-Statsd.ps1"

        $server = $args[0].split(':')
        $namespace = $args[1]

        function send($Metric, $Value) {
            $s = "$($namespace).$($Metric):$Value|g"
            Send-Statsd $s $server[0] $server[1]
        }
        function ToString() { "statsd" } }
}

# Args: foreground, background color
function console() {
    New-Module -AsCustomObject -ArgumentList $args -ScriptBlock {
        $fore = $args[0]; $back = $args[1]

        function send($Metric, $Value) {  Write-Host "$(get-date -f 'yy-MM-dd hh:mm:ss')    $Metric : $Value" -fore $fore -back $back }
        function ToString() { "console" }
    }
}

# Args: file_path
function file($fileName = "$PSScriptRoot\..\flea.txt") {
    New-Module -Name file -AsCustomObject -ArgumentList $fileName -ScriptBlock {
        $filePath = $args[0]
        function send($Metric, $Value) { "$(get-date -f 'yy-MM-dd hh:mm:ss')    $Metric : $Value" | Out-File -Append $filePath }
        function ToString() { "file" }
    }
}
