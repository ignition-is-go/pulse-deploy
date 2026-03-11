# Packer Templates

VM template builds for Proxmox. Based on [trfore/packer-proxmox-templates](https://github.com/trfore/packer-proxmox-templates).

## Setup

```bash
# Install Packer (already installed on pulse-admin)
wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com noble main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update && apt-get install packer

# Initialize plugins
packer init packer/ubuntu/.
```

## Configuration

Copy the example pkrvars and fill in your values:

```bash
cp packer/ubuntu/ubuntu.pkrvars.hcl.example packer/ubuntu/ubuntu.auto.pkrvars.hcl
```

`*.auto.pkrvars.hcl` files are gitignored and loaded automatically by Packer.

Uses the control node's existing SSH key (`~/.ssh/id_ed25519`) and `root@pam` password auth (same as Terraform).

## Build

```bash
cd packer/ubuntu
PKR_VAR_pve_password="xxx" packer build -only=ubuntu24 .
```

This will:
1. Download the Ubuntu 24.04 ISO directly to the Proxmox node
2. Boot and run unattended install via autoinstall (cloud-init)
3. Install `qemu-guest-agent` and `openssh-server`
4. Clean machine identifiers for templating
5. Convert to a Proxmox template

## Structure

```
packer/
  common/                        # Shared source + variable definitions
    pve-image.pkr.hcl            # Proxmox ISO source block
    pve-vars.pkr.hcl             # Proxmox, SSH, disk, network variables
    iso-vars.pkr.hcl             # ISO URLs, checksums, boot commands
  ubuntu/                        # Ubuntu 24.04 build
    ubuntu.pkr.hcl               # Build block
    ubuntu.pkrvars.hcl.example   # Example variable values
    configs/
      user-data                  # Autoinstall cloud-config
      cleanup.sh                 # Template cleanup script
      meta-data                  # Cloud-init metadata (required, minimal)
    *.pkr.hcl -> ../common/*     # Symlinks to shared files
```
