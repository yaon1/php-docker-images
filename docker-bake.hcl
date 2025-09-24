# Local builds of any combination: `docker buildx bake` or `docker buildx bake php84-fpm-dev`.
variable "REGISTRY" { default = "ghcr.io/yaon1/php-docker-images" }

group "default" { targets = ["php84-fpm", "php84-cli"] }

target "_base" {
  context    = "."
  platforms  = ["linux/amd64", "linux/arm64"]
}

target "php84-fpm" {
  inherits = ["_base"]
  target   = "prod"
  args     = { PHP_VERSION = "8.4", VARIANT = "fpm" }
  tags     = ["${REGISTRY}:8.4-fpm"]
}

target "php84-cli" {
  inherits = ["_base"]
  target   = "prod"
  args     = { PHP_VERSION = "8.4", VARIANT = "cli" }
  tags     = ["${REGISTRY}:8.4-cli"]
}

target "php84-fpm-dev" {
  inherits = ["php84-fpm"]
  target   = "dev"
  tags     = ["${REGISTRY}:8.4-fpm-dev"]
}

target "php84-fpm-media" {
  inherits = ["php84-fpm"]
  target   = "media"
  tags     = ["${REGISTRY}:8.4-fpm-media"]
}

target "php84-fpm-debian" {
  inherits = ["php84-fpm"]
  args     = { PHP_VERSION = "8.4", VARIANT = "fpm", DISTRO_SUFFIX = "" }
  tags     = ["${REGISTRY}:8.4-fpm-debian"]
}
