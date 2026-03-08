#!/usr/bin/env bash
# Apply Terraform targeting all VM modules EXCEPT workstation-01 and -02
# (nyc-dev-pve-02 is offline — those VMs would cause timeout errors)
set -euo pipefail

terraform apply \
  -target='module.windows_gpu_vm["touch-01"]' \
  -target='module.windows_gpu_vm["ue-content-01"]' \
  -target='module.windows_gpu_vm["ue-content-09"]' \
  -target='module.windows_gpu_vm["ue-content-10"]' \
  -target='module.windows_gpu_vm["ue-content-11"]' \
  -target='module.windows_gpu_vm["ue-content-12"]' \
  -target='module.windows_gpu_vm["ue-content-13"]' \
  -target='module.windows_gpu_vm["ue-content-14"]' \
  -target='module.windows_gpu_vm["ue-content-15"]' \
  -target='module.windows_gpu_vm["ue-content-16"]' \
  -target='module.windows_gpu_vm["ue-editing-01"]' \
  -target='module.windows_gpu_vm["ue-plugindev-01"]' \
  -target='module.windows_gpu_vm["ue-plugindev-02"]' \
  -target='module.windows_gpu_vm["ue-previs-01"]' \
  -target='module.windows_gpu_vm["workstation-03"]' \
  -target='module.windows_gpu_vm["workstation-04"]' \
  -target='module.windows_vm["ue-runner-01"]' \
  -target='module.windows_vm["ue-staging-01"]'
