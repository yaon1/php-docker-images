IMAGE ?= php-local
PHP ?= 8.4
VARIANT ?= fpm
TARGET ?= prod

.PHONY: build test lint dev

build:
	docker build --build-arg PHP_VERSION=$(PHP) --build-arg VARIANT=$(VARIANT) --target $(TARGET) -t $(IMAGE):$(PHP)-$(VARIANT)-$(TARGET) .

test: build
	tests/run.sh $(IMAGE):$(PHP)-$(VARIANT)-$(TARGET) $(VARIANT) $(TARGET)

lint:
	shellcheck -x tests/*.sh tests/cases/*.sh rootfs/usr/local/bin/* rootfs/usr/local/lib/docker-php/hooks/*.sh

dev:
	$(MAKE) test TARGET=dev
