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

Queue workers: `docker stop` sends `SIGQUIT`. Thanks to the `pcntl` extension the
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

### laravel-fpm PHP and FPM settings

Extensions on top of the official image: `bcmath exif gd intl pcntl
pdo_mysql redis zip` (`opcache`, `pdo_sqlite` come with the official image).
`php.ini-production` is active; these variables override it per container:

| Variable                          | Default   | Setting                                        |
|-----------------------------------|-----------|------------------------------------------------|
| `PHP_DISPLAY_ERRORS`              | `Off`     | `display_errors`                               |
| `PHP_MEMORY_LIMIT`                | `256M`    | `memory_limit`                                 |
| `PHP_MAX_EXECUTION_TIME`          | `30`      | `max_execution_time`                           |
| `PHP_UPLOAD_MAX_FILESIZE`         | `64M`     | `upload_max_filesize`                          |
| `PHP_POST_MAX_SIZE`               | `64M`     | `post_max_size`                                |
| `PHP_OPCACHE_MEMORY_CONSUMPTION`  | `128`     | `opcache.memory_consumption` (MB)              |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `1`       | `0` for immutable production images            |
| `PHP_FPM_PM`                      | `dynamic` | `pm`                                           |
| `PHP_FPM_PM_MAX_CHILDREN`         | `10`      | `pm.max_children`                              |
| `PHP_FPM_PM_START_SERVERS`        | `3`       | `pm.start_servers`                             |
| `PHP_FPM_PM_MIN_SPARE_SERVERS`    | `2`       | `pm.min_spare_servers`                         |
| `PHP_FPM_PM_MAX_SPARE_SERVERS`    | `5`       | `pm.max_spare_servers`                         |
| `PHP_FPM_PM_MAX_REQUESTS`         | `500`     | `pm.max_requests`                              |
| `PHP_FPM_HEALTHCHECK_ADDRESS`     | `127.0.0.1:9000` | FastCGI address the healthcheck probes  |

The image has a `HEALTHCHECK` that asks FPM's `/ping` when php-fpm runs
(queue/scheduler containers count as healthy while running). `/ping` and
`/status` are FastCGI paths of the pool; don't route them from a public
web server.
