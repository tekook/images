# Images

Repository commonly used images.

## Laravel

* [laravel fpm](https://hub.docker.com/r/tekook/laravel-fpm) (Build against 7.3.12 & 7.4.0)
* [laravel fpm with sqlsrv support](https://hub.docker.com/r/tekook/laravel-fpm-sqlsrv) (Build against 7.3.12)

### laravel-fpm entrypoint

The working directory is `/app`. On every start the entrypoint creates the
`storage/` subdirectories Laravel expects and makes `storage/` and
`bootstrap/cache` owned by `www-data` (only entries that are not already).

| First argument   | Runs (as `www-data`)                       |
|------------------|--------------------------------------------|
| *(none)* / `-…`  | `php-fpm` (with the given options)         |
| `queue …`        | `php artisan queue:work …`                 |
| `scheduler …`    | `php artisan schedule:work …` (Laravel 8+) |
| anything else    | executed as given                          |

| Variable           | Effect when `1`/`true`/`yes`/`on`                                              |
|--------------------|--------------------------------------------------------------------------------|
| `RUN_MIGRATION`    | `php artisan migrate --force` before start (not in `queue`/`scheduler` mode)   |
| `MIGRATE_ISOLATED` | adds `--isolated` to the migration (needs a shared, lock-capable cache store)  |
| `RUN_OPTIMIZE`     | `php artisan optimize` before start, in every mode                             |
| `SKIP_CHOWN`       | skips the ownership fix, e.g. for development bind mounts                      |

When the container runs as a non-root user, the ownership fix is skipped and
commands run as that user.

Queue workers: `docker stop` sends `SIGQUIT`. With the `pcntl` extension the
worker finishes its current job before exiting, so set `stop_grace_period`
above your longest job timeout:

```yaml
queue:
  image: tekook/laravel-fpm:<tag>
  command: queue --tries=3 --timeout=90
  stop_grace_period: 120s
scheduler:
  image: tekook/laravel-fpm:<tag>
  command: scheduler
```
