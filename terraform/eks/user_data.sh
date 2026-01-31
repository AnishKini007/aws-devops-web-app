#!/bin/bash
# ========================================
# EKS Node Bootstrap Script
# ========================================
# This script is executed on each node when it joins the cluster

set -ex

# Bootstrap the node with EKS
/etc/eks/bootstrap.sh ${cluster_name} ${bootstrap_arguments}

# Additional customizations can be added here:
# - Install monitoring agents
# - Configure logging
# - Set up node-level security tools
