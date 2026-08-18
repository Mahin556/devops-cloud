# Very Important: Cron expression examples

You should know these:

| Schedule       | Meaning                  |
| -------------- | ------------------------ |
| `* * * * *`    | Every minute             |
| `*/5 * * * *`  | Every 5 minutes          |
| `*/10 * * * *` | Every 10 minutes         |
| `0 * * * *`    | Every hour               |
| `0 */6 * * *`  | Every 6 hours            |
| `0 0 * * *`    | Every day at midnight    |
| `0 2 * * *`    | Every day at 2 AM        |
| `30 8 * * *`   | Every day at 8:30 AM     |
| `0 0 * * 0`    | Every Sunday at midnight |
| `0 0 1 * *`    | First day of every month |
| `0 0 1 1 *`    | January 1 every year     |
| `0 9 * * 1-5`  | Weekdays at 9 AM         |
