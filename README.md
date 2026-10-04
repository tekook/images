# Images

Docker images I commonly use. Currently one image:
[`tekook/laravel-fpm`](https://hub.docker.com/r/tekook/laravel-fpm).

## laravel-fpm

PHP-FPM for Laravel applications, built on the official `php:*-fpm` images,
as Alpine and Debian variant for `linux/amd64` and `linux/arm64`.

### Tags

| PHP    | Alpine 3.24          | Debian trixie |
|--------|----------------------|---------------|
| 8.5.11 | `2.0-8.5.11-alpine`  | `2.0-8.5.11`  |
| 8.4.26 | `2.0-8.4.26-alpine`  | `2.0-8.4.26`  |
| 8.3.35 | `2.0-8.3.35-alpine`  | `2.0-8.3.35`  |

Every image is tagged as `[<image version>-]<php version>[-alpine]`, with the
image version in full (`2.0`), as major (`2`) or left out, and the PHP version
in full (`8.4.26`) or as minor (`8.4`):

| Tag                  | Moves when                                       |
|----------------------|--------------------------------------------------|
| `2.0-8.4.26-alpine`  | the image is rebuilt (OS packages)               |
| `2.0-8.4-alpine`     | + a new PHP 8.4 patch release                    |
| `2-8.4-alpine`       | + a new 2.x image version                        |
| `8.4-alpine`         | + a new major image version (breaking changes)   |

`2.0-8.4-alpine` (or `2-8.4-alpine`) is the sensible choice for most
setups. The image version follows semver: a new major version contains
breaking changes in the entrypoint or the PHP configuration.

### Contents

- Extensions on top of the official image: `bcmath exif gd intl pcntl
  pdo_mysql redis zip`; `opcache` and `pdo_sqlite` come with the official
  image. Alpine includes the full ICU locale data for `intl`.
- `php.ini-production` as base configuration, see [settings](#php-and-fpm-settings)
- `su-exec` (Alpine) / `gosu` (Debian), `sqlite3`, `cgi-fcgi`
- Working directory `/app`, php-fpm listens on port 9000

### Usage

The application image builds on this one
(`FROM tekook/laravel-fpm:2.0-8.4-alpine`, code copied to `/app`); the same
image then runs as php-fpm, queue worker and scheduler:

```yaml
services:
  app:
    image: my-app
    environment:
      RUN_MIGRATION: "true"
      RUN_OPTIMIZE: "true"
      PHP_OPCACHE_VALIDATE_TIMESTAMPS: "0"
  queue:
    image: my-app
    command: queue --tries=3 --timeout=90
    stop_grace_period: 120s
    environment:
      RUN_OPTIMIZE: "true"
  scheduler:
    image: my-app
    command: scheduler
```

A web server in front passes PHP requests to `app:9000`, with
`SCRIPT_FILENAME` pointing to `/app/public/index.php`. For development with
the code bind-mounted to `/app`, set `SKIP_CHOWN=true` if the entrypoint
should not change the ownership of your files.

### Entrypoint

On every start the entrypoint creates the `storage/` subdirectories Laravel
expects and makes `storage/` and `bootstrap/cache` owned by `www-data`
(only entries that are not already).

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

Queue workers: `docker stop` sends `SIGQUIT`. Thanks to the `pcntl`
extension the worker finishes its current job before exiting, so set
`stop_grace_period` above your longest job timeout (see the example above).

### PHP and FPM settings

These variables override `php.ini-production` and the FPM pool per
container:

| Variable                          | Default          | Setting                                  |
|-----------------------------------|------------------|------------------------------------------|
| `PHP_DISPLAY_ERRORS`              | `Off`            | `display_errors`                         |
| `PHP_MEMORY_LIMIT`                | `256M`           | `memory_limit`                           |
| `PHP_MAX_EXECUTION_TIME`          | `30`             | `max_execution_time`                     |
| `PHP_UPLOAD_MAX_FILESIZE`         | `64M`            | `upload_max_filesize`                    |
| `PHP_POST_MAX_SIZE`               | `64M`            | `post_max_size`                          |
| `PHP_OPCACHE_MEMORY_CONSUMPTION`  | `128`            | `opcache.memory_consumption` (MB)        |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `1`              | `0` for immutable production images      |
| `PHP_FPM_PM`                      | `dynamic`        | `pm`                                     |
| `PHP_FPM_PM_MAX_CHILDREN`         | `10`             | `pm.max_children`                        |
| `PHP_FPM_PM_START_SERVERS`        | `3`              | `pm.start_servers`                       |
| `PHP_FPM_PM_MIN_SPARE_SERVERS`    | `2`              | `pm.min_spare_servers`                   |
| `PHP_FPM_PM_MAX_SPARE_SERVERS`    | `5`              | `pm.max_spare_servers`                   |
| `PHP_FPM_PM_MAX_REQUESTS`         | `500`            | `pm.max_requests`                        |
| `PHP_FPM_HEALTHCHECK_ADDRESS`     | `127.0.0.1:9000` | FastCGI address the healthcheck probes   |

### Healthcheck

The image has a `HEALTHCHECK` that asks FPM's `/ping` when php-fpm runs;
queue and scheduler containers count as healthy while running. `/ping` and
`/status` are FastCGI paths of the pool, don't route them from a public web
server.

## Building

All versions live in [`docker-bake.hcl`](docker-bake.hcl): image version,
PHP versions, distro pins and platforms. `deploy.sh` wraps
`docker buildx bake`:

```sh
./deploy.sh                                # all images, native platform, loaded into docker
./deploy.sh -l                             # list targets and groups
./deploy.sh -i laravel-fpm-8_4_26-alpine   # a single bake target
./deploy.sh -p                             # all platforms, push to Docker Hub
./deploy.sh --publisher foo                # tag as foo/laravel-fpm
./deploy.sh -- --print                     # show the resolved build definition
```

Test builds for another registry, with only a custom tag per image (e.g.
`dev-2.0-abc123-8.4.26-alpine`) and none of the release tags:

```sh
./deploy.sh -p --publisher registry.example.com/tekook \
    --tag-prefix "dev-2.0-$(git rev-parse --short HEAD)"
```

Pushing builds `linux/amd64` and `linux/arm64`, so the buildx builder needs
both platforms (native nodes or QEMU emulation).

### Updating versions

1. Change `PHP_VERSIONS`, `ALPINE_VERSION` or `DEBIAN_VERSION` in
   `docker-bake.hcl`, and `VERSION` for a new image version.
2. Check that the base images exist, e.g.
   `docker buildx imagetools inspect php:8.4.27-fpm-alpine3.24`.
3. `./deploy.sh` and test, then `./deploy.sh -p`.

### Layout

| Path                            | Purpose                                     |
|---------------------------------|---------------------------------------------|
| `docker-bake.hcl`               | versions, tags, build matrix                |
| `deploy.sh`                     | build/push wrapper                          |
| `laravel/fpm/Dockerfile.alpine` | Alpine variant                              |
| `laravel/fpm/Dockerfile.debian` | Debian variant                              |
| `laravel/fpm/conf/`             | `php.ini` overrides and FPM pool config     |
| `docker-laravel-entrypoint`     | entrypoint                                  |
| `docker-laravel-healthcheck`    | healthcheck script                          |
| `Changelog.md`                  | changes and migration notes per version     |
