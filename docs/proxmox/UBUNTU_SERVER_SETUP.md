:floppy_disk: Proxmox: Ubuntu Server Setup
NVIDIA Container Toolkit

https://stackoverflow.com/questions/72932940/failed-to-initialize-nvml-unknown-error-in-docker-after-few-hours

1. sudo vim /etc/nvidia-container-runtime/config.toml, then changed no-cgroups = false, save
2. Restart docker daemon: sudo systemctl restart docker, then you can test by running sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi 



libGL.so.1

https://stackoverflow.com/questions/55313610/importerror-libgl-so-1-cannot-open-shared-object-file-no-such-file-or-directo

apt-get update && apt-get install libgl1

