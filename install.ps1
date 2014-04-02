$files = @(ls *.ps1 -Exclude install.ps1)
if ($files.length -eq 1) { $taskName = $files[0].Name }
else {
    if (!$args.length) {  "There are $($files.length) .ps1 files in this directory.`nSpecify the one to (un)install on the command line."; exit  }

    $a = ls $args[0]
    if ($a) { $taskName = $a.Name }
    else { "File $a doesn't exist"; exit }
}

cat .\scheduled_task.xml | % { $_ -replace '!!!',"$(gi .)\$taskName"} | Out-File out.xml

schtasks.exe /End /tn $taskName 2> null
if (!$LastExitCode) {
    schtasks.exe /Delete /tn $taskName /F
}

if (($args[0] -eq '-u') -or ($args[1] -eq '-u')) { "`nUninstallation completed.`n" }
else {
    schtasks.exe /Create /XML out.xml /tn $taskName /ru "$Env:UserDomain\$Env:UserName"
    schtasks.exe /Run /tn $taskName
    schtasks.exe /tn $taskName
    "`nInstallation completed.`n"
}

rm out.xml,null
