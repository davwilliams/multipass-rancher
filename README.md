# Multipass Rancher

## What is Multipass Rancher?

Multipass Rancher is a quick set up script that can be used to create a functional Rancher lab for Linux or macOS environments via Ubuntu Multipass.

## Prerequisites

The following are the hardware and software prerequisites for common deployments:

- Sufficient CPU and memory resources to account for the K3s nodes (server and agents). Note: This can be customized (see below)
- Recent or latest release of Ubuntu Multipass installed
- Knowledge on how to import and trust Rancher-generated SSL certs

## How Does Multipass Rancher Work?

Multipass Rancher simplifies the creation of a custom-sized K3s cluster, including the Linux nodes that the cluster runs on. The script performs the following steps:

1. Captures the desired number/amount of CPUs, memory, and disk space for each K3s agent node based on user input upon running the script.
2. Creates the K3s server node with a predefined node definition and deploys K3s to it.
3. Captures key information about the K3s server node, such as IP and K3s join token.
4. Creates the desired number of K3s agent node(s) and installs K3s on them, joining them to the cluster.
5. Installs Helm on the K3s server node.
6. Installs `cert-manager` and `rancher` charts via Helm.

The Rancher installation will automatically manage the K3s cluster that it is deployed to. No need to import it post-installation.

You can then leverage Rancher to deploy or manage additional Kubernetes clusters, including Rancher-launched clusters (i.e., RKE or EKS/AKS/GKE managed clusters) or import any existing Kubernetes cluster created outside of Rancher.

Note: The K3s cluster is for lab or non-production use only. It is not hardened for production use and does not include appropriate levels of high-availability for production use.

## How to Use Multipass Rancher

Usage:

`./multipass-rancher-install.sh -w <num_agents> -c <num_cpus> -m <mem_size> -d <disk_size`

Example:

`./multipass-rancher-install.sh -w 3 -c 2 -m 4096 -d 20`

The example above will create the following:

- A K3s cluster comprised of one (1) server node and (3) agent nodes
- Each agent node will be configured with 2 vCPU and 4GB of RAM, and a 20GB virtual disk

## Components and Versions

The following are some of the included components:

- The K3s nodes will be based on the latest Ubuntu 20.04 LTS (Focal Fossa) build available from Canonical.
- The K3s version itself will be the latest stable version.
- Rancher will be based on the `latest` channel, so you have the latest and greatest features...even experimental ones.
- Certificate Manager is based on v1.2.0, which requires Kubernetes v1.16 or newer. As of 28 MAR 2021, the latest stable release was v1.20.4+k3s1; however, your build may be newer but definitely not older.

## TO DO

- Improve (or basically "add") error handling
- Add support for advanced K3s server and agent customizations
- Add support for the K3s automated upgrade controller

## Licensing

This script is governed under the MIT license.
