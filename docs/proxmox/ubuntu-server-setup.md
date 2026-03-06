# Ubuntu Server VM Gotchas

## NVIDIA Container Toolkit — "Failed to initialize NVML: Unknown Error"

After GPU passthrough, NVIDIA containers may fail after running for a few hours.

Fix: edit `/etc/nvidia-container-runtime/config.toml`, set `no-cgroups = false`, then restart Docker:
```bash
sudo systemctl restart docker
```

Ref: https://stackoverflow.com/questions/72932940/failed-to-initialize-nvml-unknown-error-in-docker-after-few-hours

## libGL.so.1 — "cannot open shared object file"

Missing OpenGL library in headless Ubuntu (common with OpenCV, PyTorch vision, etc.):
```bash
apt-get update && apt-get install libgl1
```

Ref: https://stackoverflow.com/questions/55313610/importerror-libgl-so-1-cannot-open-shared-object-file-no-such-file-or-directo
