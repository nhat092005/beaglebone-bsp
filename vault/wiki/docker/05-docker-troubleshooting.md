---
title: Docker Troubleshooting
tags:
  - docker
  - troubleshooting
date: 2026-04-18
category: docker
---

# Docker Troubleshooting

## Common Errors

### "permission denied while trying to connect to the Docker daemon"

**Cause:** User not in docker group or daemon not running.

**Solution:**

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, then test
docker ps
```

Or start daemon:

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

---

### "docker: failed to register layer"

**Cause:** Docker cache issue.

**Solution:**

```bash
sudo docker system prune -a
```

---

### "no such file or directory" when mounting

**Cause:** Path not absolute or doesn't exist.

**Solution:**

```bash
# Use absolute paths
export BSP_ROOT=/home/$USER/Working_Space/my-project/beaglebone-bsp

# Verify path exists
ls -la "${BSP_ROOT}"
```

---

### Container exits immediately

**Cause:** No TTY or command finishes too fast.

**Solution:**

```bash
# Add -it flag for interactive
docker run --rm -it -v "${BSP_ROOT}:/workspace" -w /workspace beaglebone-bsp-builder:1.0 bash
```

---

### Build fails with "No such file or directory"

**Cause:** Working directory path doesn't exist inside container.

**Solution:**

```bash
# Verify path inside container exists
docker run --rm -v "${BSP_ROOT}/u-boot:/workspace/u-boot" -w /workspace/u-boot beaglebone-bsp-builder:1.0 ls -la

# Or create directory first in Dockerfile
```

---

### "Error response from daemon: could not select driver"

**Cause:** Missing storage driver on older kernels.

**Solution:**

```bash
# Check available drivers
docker info | grep "Storage Driver"

# Use overlay2 (recommended)
echo '{"storage-driver": "overlay2"}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
```

---

## Debug Commands

### Check Docker daemon logs

```bash
sudo journalctl -u docker -f
```

### Inspect container after exit

```bash
# Use --rm=false to keep container
docker run --rm=false -it beaglebone-bsp-builder:1.0 bash
# Then: docker ps -a
```

### Check disk space

```bash
docker system df
```

### Prune everything

```bash
docker system prune -a --volumes
```
