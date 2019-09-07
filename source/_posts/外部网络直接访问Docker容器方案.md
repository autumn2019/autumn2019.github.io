---
title: 外部网络直接访问Docker容器方案
date: 2019-01-14 13:01:43
tags:
- docker
- network
- 微服务
- erueka
- 外部网络访问容器
---

# 说明  

默认情况下，一台机器上的docker容器之间是可以通过分配的IP进行通信的。  
如果容器外部要访问容器服务的话，则需要容器将其服务端口开放给宿主机，或是通过如`traefik`的API网关，将服务暴露到容器外部。  

在实际项目中，例如，在使用spring boot cloud时，会用到的erueka；在使用apollo时，也要用到erueka。  
然后，各个服务在到erueka注册时，都会使用自己的ip或是容器名，而这个ip或容器名是容器内部的，在外部网络是无法访问的。这下就尴尬了。  

erueka是一个典型，我们这次主要遇到的问题也是erueka的使用方式引起的。  
为了能在开发环境中使用docker部署的erueka，就花时间查了下资料，并给出了在外部网络中直接访问Docker容器的方案。  


# 方案

## 测试环境  


| 序号 | 项 | 值 | 说明 |
| :---: | :--- | :--- | :--- |
| 1 | 操作系统 | Ubuntu 18.04.1 LTS | |
| 2 | Docker版本 | 18.06.1-ce | - | 

## 网络信息

| 序号 | 项 | 值 | 说明 |
| :---: | :--- | :--- | :--- |
| 1 | 局域网 | 192.168.201.0/24 |  |
| 2 | 网关 | 192.168.201.1 |  |
| 3 | 网卡名称 | enp0s5 |  |
| 4 | 网桥名称 | br0 | - |  


## 操作步骤  

### 修改网卡设置  

`Ubuntu 18.04.1 LTS`的网卡设置使用`netplan`来进行管理的。  

我们需要：  
- 设置原有的网卡`enp0s5`为非dhcp设置
- 增加网桥`br0`，并将其绑定在`enp0s5`上。

修改配置文件`/etc/netplan/50-cloud-init.yaml`：

{% codeblock /etc/netplan/50-cloud-init.yml lang:yaml %}

network:
  ethernets:
    enp0s5:
      addresses: []
      dhcp4: no
      dhcp6: no
  version: 2
  bridges:
    br0:
      interfaces: [enp0s5]
      dhcp4: yes
      parameters:
        forward-delay: 0
        stp: true

{% endcodeblock %}

重启网卡：  

{% codeblock lang:bash %}
sudo netplan apply
{% endcodeblock %}


### 修改`docker`启动参数

`docker`默认是使用网桥`docker0`，我们需要修改`docker`的启动参数，使其使用我们新加的`br0`作为网桥。  

`docker`的启动配置文件为：`/etc/default/docker`。  
我们增加启动参数：`DOCKER_OPTS="-b=br0"`

修改后的配置文件如下：  

{% codeblock /etc/default/docker lang:bash %}

……

DOCKER_OPTS="-b=br0"

……
{% endcodeblock %}


修改后，重新启动`docker`引擎：

{% codeblock lang:bash %}
sudo systemctl restart  docker
{% endcodeblock %}

下面这个命令也可以：  

{% codeblock lang:bash %}
sudo /etc/init.d/docker restart
{% endcodeblock %}


至止，docker的网络设置基本完成。  

接下来，我们启动一个具体的实例，来测试一下网络的访问情况。  


## 启动测试容器

我们使用docker-compose来启动一个nginx服务。  

docker-compose.yml文件如下：  

{% codeblock nginx-demo.yml lang:yaml %}

version: '3'
services:
  nginx:
    image: nginx
    restart: always
    privileged: true

{% endcodeblock %}

保存`docker-compose.yml`后，执行以下命令，以启动容器：  

{% codeblock lang:bash %}
docker-compose up -d
{% endcodeblock %}

查看容器状态信息：  

{% codeblock lang:bash %}
server5:~/test$ docker ps 
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
06087a66c139        nginx               "nginx -g 'daemon of…"   2 minutes ago       Up 2 minutes        80/tcp              test_nginx_1
{% endcodeblock %}

查看容器`06087a66c13`的信息:  

{% codeblock lang:json %}
server5:~/test$ docker inspect 06087a66c139
[
    {
        "Id": "06087a66c139e0ee7184eea09b09ef74069ca18f7dd54326c62beb8bd8ad5092",
        "Created": "2019-01-14T14:15:50.737123692Z",
        "Path": "nginx",

……

            "MacAddress": "",
            "Networks": {
                "test_default": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": [
                        "nginx",
                        "06087a66c139"
                    ],
                    "NetworkID": "9c4ca378f98db8ef41a3581d9040f61355219ee89b29ca80d63a22ed7a394138",
                    "EndpointID": "88f71955499b7249a73f87b864f044ca6bfbf6d80e17fc8ad8f02b2cd63d7d86",
                    "Gateway": "172.22.0.1",
                    "IPAddress": "172.22.0.2",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:ac:16:00:02",
                    "DriverOpts": null
                }
            }
        }
    }
]

{% endcodeblock %}

由上面的输出可以看到，其IP地址为： `172.22.0.2`。


## 访问测试

### 查看容器桥接网卡`br0`的ip

在容器的宿主机上，使用`ifconfig`命令可以查看`br0`的ip地址：  

{% codeblock lang:bash %}
server5:~/test$ ifconfig br0
br0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.201.239  netmask 255.255.255.0  broadcast 192.168.201.255
        inet6 fe80::4c68:f2ff:feac:809  prefixlen 64  scopeid 0x20<link>
        ether 4e:68:f2:ac:08:09  txqueuelen 1000  (Ethernet)
        RX packets 10655665  bytes 2097194705 (2.0 GB)
        RX errors 0  dropped 4  overruns 0  frame 0
        TX packets 10536545  bytes 2158837188 (2.1 GB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
{% endcodeblock %}

可以看到，`ip`为`192.168.201.239`。当然，此处的ip也可以设为静态ip。

### 设置客户机路由

在客户机上设置容器地址的访问路由：  
> 看得到，容器分配的ip地址为172.16.0.0~172.31.255.255区间内的B内保留地址。

{% codeblock 此为Mac OS下的命令 lang:bash %}
sudo route -n add -net 172.16.0.0 -netmask 255.240.0.0 192.168.201.239
{% endcodeblock %}

### 浏览器查看

由于我们启动的是nginx容器，因此，我们在浏览器端直接可以访问地址：  
`http://172.22.0.2/`

你如果可以看到nginx的默认首页，就说明，我们可以直接访问到容器的服务了。  

# 补充（Ubuntu 16.04）

## 桥接网络设置

```
sudo apt-get install -y bridge-utils

```


# 最后

容器的ip可以直接访问了，那么，接下来我们会进行`Apollo`的配置以及`spring boot cloud`的配置。这两个都会使用`erueka`服务。  
