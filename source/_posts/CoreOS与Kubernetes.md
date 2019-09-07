---
title: CoreOS与Kubernetes
date: 2019-06-13 16:59:16
tags: 
  - CoreOS
  - K8s
  - Kubernetes
  - Docker
---

# 前言

在此之前，运行Docker的环境，主要是以Ubuntu主机为主，编排工具也主要是docker-compose。  
到现在，docker-compose以逐渐不能满足我们日常对运维部署的需要，而kubernetes也日益的作为我们日常应用部署的主要编排工具。  

随之，CoreOS也进入了替代Ubuntu作为我们docker运行的宿主操作系统的日程。  

本文主要记录CoreOS及Kubernetes的安装工作。  

# CoreOS的安装

## 镜像制作


## ignition.yaml及ignition.json

### ignition.yaml

{% codeblock lang:yaml ignition.yaml %}
etcd:
  version: 3.1.6
  name: coreos91
  advertise_client_urls: http://192.168.10.91:2379
  initial_advertise_peer_urls: http://192.168.10.91:2380
  listen_client_urls: http://0.0.0.0:2379
  listen_peer_urls: http://192.168.10.91:2380
  initial_cluster: coreos91=http://192.168.10.91:2380

passwd:
  users:
    - name: core
      password_hash: "$6$rounds=4096$xZ9xIGea/SY$jLa.mSbH0UYZB9AjjOrvG.njyUiJBWs1lTGDCe.9ORRhWxhDdAG/b64D1ae/E4IJECnUOpH1r0pOvJPyvPDXE1"
      ssh_authorized_keys: 
        - ssh-rsa  AAAAB3NzaC1yc2EAAAADAQABAAABAQDEObKTPr7gijPRdXDMfAQrmnhO6ZQz8pp+gXIx5h66bGhNrqWsq+IaMeujzkNskvP3NOmszU6BlsA3OEx6UWmmwawff/G04YUNXxDtI9Bx5GO1JW+dxr/unP33mhwMaQplKlvyuDAJwVMHHKIsn5NJv3qpfJhdWcHKK8/z1lXlwdie6sf/qKuNdo/WL3o4p5/K7IS+bkP7q6VeqHWl+jBEh1GzMtvcGLLhNpDggZH5SraAhtqK6bP51FUs/DrvdnXW6R8iQs2k2KMm6aCDq7NICO/2/YgOJN8sT9xLEynD39fqek58nqySks916//GUKPjA9bgJAPcbAPZ80B4+GQr
      groups: 
        - wheel 
        - sudo 
        - docker

systemd:
  units:
    - name: flanneld.service
      enable: true
      dropins:
      - name: 50-network-config.conf
        contents: |
          [Service]
          ExecStartPre=/usr/bin/etcdctl set /coreos.com/network/config '{"Network":"10.1.0.0/16", "Backend": {"Type": "vxlan"}}'


networkd:
  units:
    - name: static.network
      contents: |
        [Match]
        Name=enp0s31f6

        [Network]
        Address=192.168.10.91/24
        Gateway=192.168.10.1

storage:
  files:
    - filesystem: "root"
      path:       "/etc/hostname"
      mode:       0644
      contents:
        inline: coreos91
    - filesystem: "root"
      path:       "/etc/resolv.conf"
      mode:       0644
      contents:
        inline: |
          nameserver 192.168.10.1
{% endcodeblock %}

### ignition.json

{% codeblock lang:yaml ignition.json %}
{
	"ignition": {
		"config": {},
		"security": {
			"tls": {}
		},
		"timeouts": {},
		"version": "2.2.0"
	},
	"networkd": {
		"units": [{
			"contents": "[Match]\nName=enp0s31f6\n\n[Network]\nAddress=192.168.10.91/24\nGateway=192.168.10.1\n",
			"name": "static.network"
		}]
	},
	"passwd": {
		"users": [{
			"groups": ["wheel", "sudo", "docker"],
			"name": "core",
			"passwordHash": "$6$rounds=4096$xZ9xIGea/SY$jLa.mSbH0UYZB9AjjOrvG.njyUiJBWs1lTGDCe.9ORRhWxhDdAG/b64D1ae/E4IJECnUOpH1r0pOvJPyvPDXE1",
			"sshAuthorizedKeys": ["ssh-rsa  AAAAB3NzaC1yc2EAAAADAQABAAABAQDEObKTPr7gijPRdXDMfAQrmnhO6ZQz8pp+gXIx5h66bGhNrqWsq+IaMeujzkNskvP3NOmszU6BlsA3OEx6UWmmwawff/G04YUNXxDtI9Bx5GO1JW+dxr/unP33mhwMaQplKlvyuDAJwVMHHKIsn5NJv3qpfJhdWcHKK8/z1lXlwdie6sf/qKuNdo/WL3o4p5/K7IS+bkP7q6VeqHWl+jBEh1GzMtvcGLLhNpDggZH5SraAhtqK6bP51FUs/DrvdnXW6R8iQs2k2KMm6aCDq7NICO/2/YgOJN8sT9xLEynD39fqek58nqySks916//GUKPjA9bgJAPcbAPZ80B4+GQr"]
		}]
	},
	"storage": {
		"files": [{
			"filesystem": "root",
			"path": "/etc/hostname",
			"contents": {
				"source": "data:,coreos91",
				"verification": {}
			},
			"mode": 420
		}, {
			"filesystem": "root",
			"path": "/etc/resolv.conf",
			"contents": {
				"source": "data:,nameserver%20192.168.10.1%0A",
				"verification": {}
			},
			"mode": 420
		}]
	},
	"systemd": {
		"units": [{
			"dropins": [{
				"contents": "[Service]\nEnvironment=\"ETCD_IMAGE_TAG=v3.1.6\"\nExecStart=\nExecStart=/usr/lib/coreos/etcd-wrapper $ETCD_OPTS \\\n  --name=\"coreos91\" \\\n  --listen-peer-urls=\"http://192.168.10.91:2380\" \\\n  --listen-client-urls=\"http://0.0.0.0:2379\" \\\n  --initial-advertise-peer-urls=\"http://192.168.10.91:2380\" \\\n  --initial-cluster=\"coreos91=http://192.168.10.91:2380\" \\\n  --advertise-client-urls=\"http://192.168.10.91:2379\"",
				"name": "20-clct-etcd-member.conf"
			}],
			"enable": true,
			"name": "etcd-member.service"
		}, {
			"dropins": [{
				"contents": "[Service]\nExecStartPre=/usr/bin/etcdctl set /coreos.com/network/config '{\"Network\":\"10.1.0.0/16\", \"Backend\": {\"Type\": \"vxlan\"}}'\n",
				"name": "50-network-config.conf"
			}],
			"enable": true,
			"name": "flanneld.service"
		}]
	}
}
{% endcodeblock %}

# Kubernetes的安装



# 附录

## 附录一 Cluster TLS using OpenSSL

参考地址：{% link "Cluster TLS using OpenSSL" https://coreos.com/kubernetes/docs/1.0.6/openssl.html  %}


{% codeblock lang:shell %}
export K8S_SERVICE_IP=10.3.0.1
export MASTER_HOST=192.168.10.91

openssl genrsa -out ca-key.pem 2048

openssl req -x509 -new -nodes -key ca-key.pem -days 10000 -out ca.pem -subj "/CN=kube-ca"

{% endcodeblock %}



## 一些CoreOS命令

{% codeblock lang:shell %}

sudo hostnamectl set-hostname coreos1 #修改主机名
setenforce 1/0 #开启关闭SELinux
getenforce #查看SELinux状态
timedatectl #查看系统时间
timedatectl list-timezones #查看支持的时区列表
timedatectl set-timezone Asia/Shanghai #设置时区为上海

{% endcodeblock %}