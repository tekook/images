# Build definition for all images, see deploy.sh for the usual invocations.
# Every version lives here: image version, PHP versions and distro pins.

# image version, first part of every tag
variable "VERSION" {
  default = "2.0"
}

variable "PUBLISHER" {
  default = "tekook"
}

# PHP releases to build, one per supported minor version
variable "PHP_VERSIONS" {
  default = ["8.3.35", "8.4.26", "8.5.11"]
}

# distro releases of the php base images (php:<version>-fpm-alpine<x>,
# php:<version>-fpm-<debian>)
variable "ALPINE_VERSION" {
  default = "3.24"
}

variable "DEBIAN_VERSION" {
  default = "trixie"
}

variable "PLATFORMS" {
  default = ["linux/amd64", "linux/arm64"]
}

# Tags for one image: every combination of image version (full, major.minor,
# major, none; duplicates dropped) and PHP version (8.4.24, 8.4), e.g.
# 2.0-8.4.24-alpine, 2-8.4-alpine, 8.4-alpine.
function "tags" {
  params = [image, php, suffix]
  result = flatten([
    for prefix in distinct([
      "${VERSION}-",
      "${join(".", slice(split(".", VERSION), 0, min(2, length(split(".", VERSION)))))}-",
      "${split(".", VERSION)[0]}-",
      "",
    ]) : [
      for p in [php, join(".", slice(split(".", php), 0, 2))] :
        "${PUBLISHER}/${image}:${prefix}${p}${suffix}"
    ]
  ])
}

group "default" {
  targets = ["laravel-fpm"]
}

target "laravel-fpm" {
  name = "laravel-fpm-${replace(php, ".", "_")}-${distro}"
  matrix = {
    php    = PHP_VERSIONS
    distro = ["alpine", "debian"]
  }
  context    = "."
  dockerfile = "laravel/fpm/Dockerfile.${distro}"
  args = {
    PHP_VERSION    = php
    ALPINE_VERSION = ALPINE_VERSION
    DEBIAN_VERSION = DEBIAN_VERSION
  }
  # debian images keep the suffix-less tags, as before
  tags      = tags("laravel-fpm", php, distro == "alpine" ? "-alpine" : "")
  platforms = PLATFORMS
  pull      = true
}
