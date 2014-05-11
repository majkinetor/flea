Flea
===

Flea is Powershell function scheduler with option to send the function results to arbitrary number of backends. Functions are executed as Powershell background jobs. Flea requires minimum Powershell 3.0.

Here is the simple script that runs few monitoring functions:

```PowerShell
. "$PSScriptRoot\inc\flea.ps1"

flea @{
    freq       = 10;
    backends   = @(
        ,(statsd "11.22.33.44:8125" "myapp.servers.$($Env:ComputerName)")
        ,(file "out.txt")
        ,(console yellow red)
    );
    debug      = 1;
    monitors   = @(
            , ("cpu_load",  -1,          "cpu_load",  9)
            , ("ram_free",  6,           "ram_free")
            , ("disk_c",    '00:00/24h', "disk_free", "c:")
            , ("sql_count", "*:10/-1h",  "sql_count", $db, "Table")
    )
}
```

Arguments
---------
Flea accepts `[HashTable]` configuration argument with the following attributes:

- `freq` <br/>
Frequency of the main timer in seconds. This timer starts immediately upon executing flea and runs all functions that define `trigger` as number.
- `backends` <br/>
Array of backend objects that implement `Send($Name, $Value)` method. Backends are defined in `inc\backends.ps`.
- `debug` <br/>
Enables listing of detailed information in console while running. To see function results, use debug with `console` backend.
- `init_script`<br/>
Path to Powershell script to be included with the executing function. As functions are executed as background jobs any functions you define will not be seen from the job. As alternative, you can define functions inside file `inc\common_metrics.ps1` which is included with all functions and contains several useful monitoring functions.
- `monitors` <br/>
Array of scheduled function definitions. Each element contains array with the following attributes:
  - `name` <br/>
  Name of the definition.
  - `trigger` <br/>
  Defines time and frequency of execution. If it is a number it represents iteration in which the function will run relative to the main timer. If it is a string it defines how to run the function outside the main timer context. The string is in the form `<hour|*>[:min|*]/[-]freq[h|m]` where:
    - `hour:min` is starting time of the function. Flea will wait for this time after which it will start the execution of the function. `*` means any hour or minute. If `min` is not specified it defaults to `*`.
    - `freq` is the frequency that applies only for this function. A negative frequency means to stop executing the function if it is still running when the next trigger time comes (outputs "_restarting: < name >_" in debug mode). A positive frequency means that flea will wait for the previous execution to finish (outputs "_still running: < name >_" in debug mode), that is, the function will be skipped until the next trigger time. The `h|m` after frequency denotes _hour_ and _minute_. Without any specifier the number represents seconds.<br/>
  - `function`<br/>
  Name of the function to run. Function must be defined in either `inc\common_metrics.ps1` or custom include which you can specify using `init_script` option. If prefixed with `.` char, the function will be redeclared within its background job. If the function needs to include other scripts those must be specified either by using hard-coded path or by starting with `$PSScriptRoot` variable. Include must be present inside the function body. <br/>
  Function must return either numeric value or HashTable. If it returns HashTable each of its items will be sent to the defined backends - key will be used as a `$Name` and its value as `$Value` argument of the `Send($Name, $Value)` function implemented by the particular backend. 
  - `function arguments`<br/>
  List of function arguments, max 5.<br/>
  <br/>**Trigger examples**:<br/>
    `*/3`<br/> Runs imediatelly, repeat every 3 seconds afterwards.<br/>
    `*:10/-1h`<br/> Runs on 10th minute of any hour, repeats once per hour and restarts the previous instance if it is still running.<br/>
    `22:*/10m`<br/> Starts on any minute of the 22th hour and repeats every 10 minutes after that.<br/>
    `3`<br/> Starts imediatelly and uses the main timer that runs with frequency defined in the main configuration. Repeats every 3 iterations. If the `freq = 10` this will run the function every 30 seconds.

Notes
-----
- To stop flea execution when running in debug mode, press CTRL-c.
- Script `install.ps1` can be used to install Powershell file that executes flea configuration in Windows Task Scheduler as a task that runs immediately and is scheduled to run on boot with elevated privileges. Elevated rights are currently used because common metric `cpu_load` requires it (as it uses `get-counter` to obtain the metrics). If you run it without any arguments and folder contains only single Powershell file, it will install that file. Otherwise specify file name on the command line. The second argument is `-u` which can be used to uninstall the task.

TODO
----
- More trigger options - delay, stop time, list of hours, precise date.
- Each function to have its own configuration, and the current configuration to act as default if nothing is specified.
- Accept hash instead of array for function specification.
