Flea
====

Flea is Powershell function scheduler with option to send the function results to arbitrary number of backends. Functions are executed as Powershell background jobs.

Here is the simple script that runs few monitoring functions:

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

Arguments
---------
Flea accepts `[HashTable]` configuration argument with the following attributes:

- `freq` <br/>
Frequency of the main timer in seconds. This timer starts immediately upon executing flea and run all functions that define `trigger` as number.
- `backends` <br/>
Array of backend objects that implement `Send($Name, $Value)` method.
- `debug` <br/>
Enables listing of detailed information in console while running. To see function results use with `console` backend.
- `init_script`<br/>
Path to Powershell script to be included with the executing function. As functions are executed as background jobs any functions you define will not be seen from the job. As alternative, you can define functions inside file `inc\common_metrics.ps1` which is included with all functions.
- `monitors` <br/>
Array of specification for the functions to run. Each containing array specifies the following:
  - `name` <br/>
  Name of the specification
  - `trigger` <br/>
  Defines time and frequency of execution. If it is number, represents iteration in which function will run relative to the main timer. If it is string, represents how to run function without the main timer context. The string is in the form `<hour|*>[:min|*]/[-]freq[h|m]` where 
    - `*` represents "any hour or minute". If minute is not specified it is assumed it is `*`.
    - Negative frequency means to stop executing job if it is still running when the next trigger time comes before previous function execution is finished. Otherwise, the flea wait for the previous execution to finish (and outputs "_still running: name_" in debug mode).
    - `h|m` after frequency denotes 'hour' and 'minute'. Without any specifier the number represents seconds.<br/><br/>
    **Examples**:<br/>
    `*/3`<br/> Runs imediatelly and after every 3 seconds.<br/>
    `*:10/-1h`<br/> Runs on 10th minute of any hour, repeats once pee hour and kills the previous instance if running.<br/>
    `22:*/10m`<br/> Runs on any minute of 22th hour and repeats every 10 minutes.<br/>
     `3`</br>Uses main timer that runs with `freq` frequency and starts imediatelly. Repeats every 3 iterations. If the `freq = 10` this will run the function every 30 seconds.
  - `function`</br>
  Name of the function to run. Function must be defined in either `inc\common_metrics.ps1` or custom include which you can specify using `init_script` option.
  - `function arguments`<br/>
  List of function arguments, max 5.

Notes
-----
- To stop flea execution when running in debug mode, press CTRL-c.
- Script `install.ps1` can be used to install Powershell file that executes flea configuration in Windows Task Scheduler as a task that runs immediately and is scheduled to run on boot with elevated privileges. Elevated rights are currently used because common metric `cpu_load` requires it (as it uses `get-counter` to obtain the metrics). If you run it without any arguments and folder contains only single Powershell file, it will install that file. Otherwise specify file name on the command line. The second argument is `-u` which can be used to uninstall the task.

TODO
----
- More trigger options - delay, stop time, list of hours, precise date.
- Each function to have its own configuration, and the current configuration to act as default if nothing is specified.
- Accept hash instead of array for function specification.
