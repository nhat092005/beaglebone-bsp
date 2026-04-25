---
title: Docker Installation
tags:
  - docker
  - install
date: 2026-04-18
category: docker
---

# Docker Installation

## Docker Engine on Ubuntu 22.04

### Step 1: Update and install dependencies

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
```

### Step 2: Add Docker GPG key

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

### Step 3: Add Docker repository

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Step 4: Install Docker

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd docker-buildx-plugin docker-compose-plugin
```

### Step 5: Add user to docker group

```bash
sudo usermod -aG docker $USER
```

> **Note:** Log out and back in for group membership to take effect.

## Verify Installation

```bash
# Test Docker is running
sudo docker run --rm hello-world

# List images
docker images
```

## Troubleshooting

| Issue                     | Solution                                        |
| ------------------------- | ----------------------------------------------- |
| Docker daemon not running | `sudo systemctl start docker`                   |
| User not in docker group  | `sudo usermod -aG docker $USER` then log out/in |
