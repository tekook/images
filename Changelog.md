# Changelog

## laravel-fpm 2.0

PHP 8.2.35, 8.3.36, 8.4.27 and 8.5.12, each as Alpine 3.24 and Debian trixie
variant for `linux/amd64` and `linux/arm64`.

No existing tag changes: 2.0 is published only for new PHP versions, so the
1.x tags (`1.1-8.4.24-alpine`, `1-8.4.24-alpine`, `8.4.24-alpine`, …) keep
pointing to 1.1. Switching to 2.0 is always an explicit tag change.

### Breaking changes and migration

| Change | Before (1.x) | Now (2.0) | What to do |
|---|---|---|---|
| Scheduler | `scheduler` set up a crontab for busybox `crond`; extra arguments went to `crond` | `scheduler` runs `php artisan schedule:work` as `www-data`, extra arguments go to `schedule:work` | Needs Laravel 8+. Drop `crond` options from the command. Scheduler output is now in the container log. |
| `RUN_MIGRATION` | any non-empty value migrated, including `false` and `0` | only `1`, `true`, `yes`, `on` (any case) | Use `RUN_MIGRATION=true`. |
| Migration user | `migrate` ran as root | runs as `www-data` | Files the migration writes must be writable by `www-data`, e.g. a SQLite database outside `storage/`. |
| PHP configuration | no `php.ini`, PHP built-in defaults | `php.ini-production` plus overrides from `PHP_*` variables | See the table below; set `PHP_DISPLAY_ERRORS=On` if a development setup relied on displayed errors. |
| FPM pool | 5 children (2 start, 1–3 spare), workers never recycled | 10 children (3 start, 2–5 spare), recycled after 500 requests | Check memory limits of the container; tune via `PHP_FPM_PM*`. |
| Ownership fix | `chown -R` of `storage/` on every start | only entries not owned by `www-data`, now also `bootstrap/cache`, symlinks not followed; skipped for non-root containers | Set `SKIP_CHOWN=true` to keep the entrypoint away from bind-mounted files. |
| Healthcheck | none | `HEALTHCHECK` probing FPM's `/ping` every 30s | Orchestrators (e.g. Swarm) now replace unhealthy containers. If php-fpm listens somewhere else than `127.0.0.1:9000`, set `PHP_FPM_HEALTHCHECK_ADDRESS`. |
| Build dependencies | `*-dev` packages stayed in the image | removed after compiling the extensions | Derived images that run `docker-php-ext-install` must install the needed `-dev` packages (and on Alpine `$PHPIZE_DEPS`) themselves. |
| PHP 8.1 | 8.1.34 | not built anymore | Upgrade to 8.2+, or stay on the 1.x tags. |

PHP setting changes through `php.ini-production` and the new defaults:

| Setting | 1.x | 2.0 | Variable |
|---|---|---|---|
| `display_errors` | `On` (errors in the HTTP response) | `Off` | `PHP_DISPLAY_ERRORS` |
| `expose_php` | `On` | `Off` | – |
| `error_reporting` | unset, PHP default `E_ALL` | `E_ALL & ~E_DEPRECATED` | – |
| `memory_limit` | `128M` | `256M` | `PHP_MEMORY_LIMIT` |
| `upload_max_filesize` | `2M` | `64M` | `PHP_UPLOAD_MAX_FILESIZE` |
| `post_max_size` | `8M` | `64M` | `PHP_POST_MAX_SIZE` |
| `opcache.interned_strings_buffer` | `8` | `16` | – |
| `opcache.max_accelerated_files` | `10000` | `20000` | – |

### Added

- Extensions `pcntl` (graceful queue worker shutdown, `queue:work
  --timeout`), `intl`, `exif`, `redis` (phpredis 6.3.0); Alpine ships the
  full ICU locale data (`icu-data-full`)
- PHP 8.5
- `RUN_OPTIMIZE` runs `php artisan optimize` on start, in every mode
- `MIGRATE_ISOLATED` adds `--isolated` to the migration
- `SKIP_CHOWN` disables the ownership fix
- Containers running as a non-root user are supported
- `PHP_*` / `PHP_FPM_*` variables for PHP and pool settings, see README
- FPM `ping.path` (`/ping`) and `pm.status_path` (`/status`), `cgi-fcgi`
  in the image, healthcheck script `docker-laravel-healthcheck`
- PHP-minor tags (`2.0-8.4-alpine`, `8.4-alpine`, …), see README

### Fixed

- `scheduler` failed on the Debian variants (`crontab: not found`)
- the crontab entry was appended again on every container restart, so the
  schedule ran once per restart each minute
- `RUN_MIGRATION=false` still ran migrations
- arguments with spaces were split in `queue` and `scheduler` mode
- broken `su -c` fallback in the entrypoint removed
- Debian: `gosu` install could abort the build (missing `-y`)

### Changed (repository / build)

- One `Dockerfile.alpine` and one `Dockerfile.debian` instead of a folder
  per PHP version; all versions in `docker-bake.hcl`, built with
  `docker buildx bake` (`laravel/fpm/VERSION` removed)
- Base images pinned to a distro release (`alpine3.24`, `trixie`)
- `deploy.sh` wraps bake: exits non-zero on failed builds, always pulls
  base images, `-i` takes a bake target, unknown options are rejected
- Removed the unmaintained `laravel-fpm-sqlsrv`, `wordpress` and `test`
  images
