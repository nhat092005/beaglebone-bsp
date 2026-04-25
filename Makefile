IMAGE       ?= bbb-builder
HOST        ?= 192.168.7.2
TFTP_DIR    ?= /srv/tftp
DEV         ?= /dev/sdb
DRIVER ?=
WS     ?= $(HOME)/Working_Space
BB     ?= core-image-minimal

DOCKER_RUN = docker run --rm \
  -v $(PWD):/workspace \
  -v $(WS):/home/builder/ws \
  $(IMAGE)

DOCKER_IT = docker run --rm -it \
  -v $(PWD):/workspace \
  -v $(WS):/home/builder/ws \
  $(IMAGE)

.PHONY: all kernel uboot driver docker shell yocto-shell bitbake deploy flash clean kernel-clean uboot-clean check help

help:
	@echo "BeagleBone Black BSP"
	@echo ""
	@echo "Build (runs inside Docker):"
	@echo "  make kernel               Build zImage + dtbs + modules"
	@echo "  make uboot                Build MLO + u-boot.img"
	@echo "  make driver DRIVER=<name> Build out-of-tree driver"
	@echo "  make all                  Build kernel + uboot + all drivers"
	@echo ""
	@echo "Yocto:"
	@echo "  make yocto-shell          Interactive shell with Yocto env loaded"
	@echo "  make bitbake BB=<target>  Run bitbake (default: core-image-minimal)"
	@echo ""
	@echo "Docker:"
	@echo "  make docker               Build Docker image ($(IMAGE))"
	@echo "  make shell                Interactive shell in Docker container"
	@echo ""
	@echo "Board:"
	@echo "  make deploy TFTP_DIR=<path>   Copy kernel + dtb to TFTP dir (default: $(TFTP_DIR))"
	@echo "  make flash  DEV=<dev>     Flash SD card (default: $(DEV)) — requires root"
	@echo ""
	@echo "Clean:"
	@echo "  make clean                Remove build/ directory"
	@echo "  make kernel-clean         Clean kernel build artifacts"
	@echo "  make uboot-clean          Clean U-Boot build artifacts"
	@echo ""
	@echo "Quality:"
	@echo "  make check                Run shellcheck + checkpatch on scripts and drivers"

.check-docker:
	@docker image inspect $(IMAGE) >/dev/null 2>&1 || \
		(echo "Error: Docker image '$(IMAGE)' not found. Run 'make docker' first." && exit 1)

docker:
	docker build -f docker/Dockerfile -t $(IMAGE) .

kernel: .check-docker
	$(DOCKER_RUN) bash scripts/build.sh kernel

uboot: .check-docker
	$(DOCKER_RUN) bash scripts/build.sh uboot

driver: .check-docker
	@test -n "$(DRIVER)" || (echo "Error: specify DRIVER=<name>  e.g. make driver DRIVER=led-gpio" && exit 1)
	$(DOCKER_RUN) bash scripts/build.sh driver $(DRIVER)

all: .check-docker
	$(DOCKER_RUN) bash scripts/build.sh all

shell: .check-docker
	$(DOCKER_IT) bash

yocto-shell: .check-docker
	$(DOCKER_IT) bash -c "cd /home/builder/ws/poky && source oe-init-build-env /workspace/build && exec bash"

bitbake: .check-docker
	$(DOCKER_IT) bash -c "cd /home/builder/ws/poky && source oe-init-build-env /workspace/build && bitbake $(BB)"

deploy:
	TFTP_DIR=$(TFTP_DIR) bash scripts/deploy.sh

flash:
	sudo bash scripts/flash_sd.sh $(DEV)

clean:
	rm -rf build/

kernel-clean: .check-docker
	$(DOCKER_RUN) bash -c "cd linux && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- clean"

uboot-clean: .check-docker
	$(DOCKER_RUN) bash -c "cd u-boot && make CROSS_COMPILE=arm-linux-gnueabihf- clean"

check: .check-docker
	$(DOCKER_RUN) shellcheck scripts/*.sh
	$(DOCKER_RUN) bash -c "if [ -d drivers ]; then for d in drivers/*/; do [ -f \$$d/*.c ] && linux/scripts/checkpatch.pl --strict -f \$$d/*.c || true; done; fi"
