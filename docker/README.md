# Docker Build Environment

Single image containing the full BeagleBone Black cross-compile toolchain plus Yocto dependencies.

## Build

```bash
docker build -f docker/Dockerfile -t bbb-builder .
```

## Run

Mount the repo root as `/workspace` and run build commands inside the container:

```bash
docker run --rm -v $(pwd):/workspace bbb-builder bash scripts/build.sh all
```

Run a single target:

```bash
docker run --rm -v $(pwd):/workspace bbb-builder bash scripts/build.sh kernel
docker run --rm -v $(pwd):/workspace bbb-builder bash scripts/build.sh uboot
docker run --rm -v $(pwd):/workspace bbb-builder bash scripts/build.sh driver led-gpio
```

Interactive shell:

```bash
docker run --rm -it -v $(pwd):/workspace bbb-builder bash
```

## Environment

| Variable        | Value                                    |
| --------------- | ---------------------------------------- |
| `CROSS_COMPILE` | `arm-linux-gnueabihf-`                   |
| `ARCH`          | `arm`                                    |
| `WORKDIR`       | `/workspace`                             |
| Default user    | `builder` (UID 1000) — required by Yocto |
