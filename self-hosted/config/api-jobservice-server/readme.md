| api-jobservice-server\appsettings.json                                                                                    | Description                                  |
|---------------------------------------------------------------------------------------------------------------------------|----------------------------------------------|
| {                                                                                                                         |                                              |
|   "ConnectionStrings": {                                                                                                  |                                              |
|     "TwApiDatabase": "Server=???????;Database=???????;User Id=???????;Password=???????;MultipleActiveResultSets=True;",   | Login server database SQL connection string. |
|     "RebusDatabase": "Server=???????;Database=???????;User Id=???????;Password=???????;MultipleActiveResultSets=True;",   | Rebus database SQL connection string.        |
|     "HangfireDatabase": "Server=???????;Database=???????;User Id=???????;Password=???????;MultipleActiveResultSets=True;" | Hangfire database SQL connection string.     |
|   },                                                                                                                      |                                              |
|   "Hangfire": {                                                                                                           | Hangfire worker process settings.            |
|     "Dashboard": {                                                                                                        |                                              |
|       "IsDashboardActive": "True",                                                                                        |                                              |
|       "AppPath": "/",                                                                                                     |                                              |
|       "StatsPollingInterval": 2000                                                                                        |                                              |
|     },                                                                                                                    |                                              |
|     "Server": {                                                                                                           |                                              |
|       "HeartbeatInterval": "00:00:30",                                                                                    |                                              |
|       "Queues": [ "all" ],                                                                                                |                                              |
|       "SchedulePollingInterval": "00:00:15",                                                                              |                                              |
|       "ServerCheckInterval": "00:05:00",                                                                                  |                                              |
|       "ServerName": null,                                                                                                 |                                              |
|       "ServerTimeout": "00:05:00",                                                                                        |                                              |
|       "ShutdownTimeout": "00:00:15",                                                                                      |                                              |
|       "WorkerCount": 20                                                                                                   |                                              |
|     }                                                                                                                     |                                              |
|   },                                                                                                                      |                                              |
|   "AppSettings": {                                                                                                        |                                              |
|     "SharedTempDirectory": "C:\\app\\shared-temp"                                                                         |                                              |
|   },                                                                                                                      |                                              |
|   "EventGrid": {                                                                                                          |                                              |
|     "Primary": {                                                                                                          |                                              |
|       "TopicUrl": "",                                                                                                     |                                              |
|       "TopicKey": ""                                                                                                      |                                              |
|     },                                                                                                                    |                                              |
|     "Secondary": {                                                                                                        |                                              |
|       "TopicUrl": "",                                                                                                     |                                              |
|       "TopicKey": ""                                                                                                      |                                              |
|     }                                                                                                                     |                                              |
|   }                                                                                                                       |                                              |
| }                                                                                                                         |                                              |
