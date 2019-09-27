---
title: Apollo配置中心部署指南（kubernetes）
date: 2019-01-11 18:38:37
tags:
  - 微服务
  - 容器云
  - Kubernetes
  - k8s
  - 配置中心
  - spring boot
categories:
- 微服务
---

# 前言

采用微服务，就必须启动应用配置中心，否则的话，很多个应用，部署时的配置就非常繁琐。  

即使不用微服务，多种运行环境的管理也是很麻烦。`DEV`、`TEST ALPHA`、`TEST BETA`、`PROD`，众多的项目，其实本身就是个麻烦。  

对于`spring boog cloud`框架下的微服务，`spring projects`本身有提供`spring cloud config`用于作配置中心。但是有以下原因：

- 其配置管理是基于文件形式的，如git库这种；
- 没有图形化的管理界面；
- 对于多个项目+多个环境，组合下来，对于一个系统，配置文件就比较多了，管理上也就稍显麻烦

因此，建立一套功能完善易用的配置中心，势在必行。  

当前配置中心有： 
- {% link spring-cloud/spring-cloud-config https://github.com/spring-cloud/spring-cloud-config  %}
- {% link 淘宝 diamond https://github.com/takeseem/diamond %}
- {% link disconf https://github.com/knightliao/disconf %}
- {% link ctrip apollo https://github.com/ctripcorp/apollo/ %}

关于这四种配置中心的功能比较，可参见网页 {% link 统一配置中心选型对比https://www.cnblogs.com/xiaoqi/p/configserver-compair.html %}一文。

对于我们自己而言，后台开发主要使用的是`spring boot`及`spring boot cloud`，而类似于数据库的配置是需要在程序启动的时候，就要配置好的，否则，程序连不上库会直接退出。  
而在列表里，只有`spring-cloud/spring-cloud-config`和`ctrip apollo`可以满足上面的要求。  
同时，前面也说了一些`spring-cloud/spring-cloud-config`的不足之处，所以，我们最终选定使用`ctrip apollo`作为我们的配置中心。  

下面，记录下本次`ctrip apollo`的安装及部署过程。  
 
# kubernets下安装步骤

## 装备名字空间

因为我们要将apollo作为当前及以后的所有系统的配置中心，因此，我们将系统在kubernetes下的namespace定为`kestrel-cloud-center`。

{% codeblock kestrel-cloud-center-namespace.yml lang:yaml %}
apiVersion: v1
kind: Namespace
metadata:
  name: kestrel-cloud-center
{% endcodeblock %}

## 准备kubernetes的存储pv和pvc

我们当前使用一台做了raid-0阵列的主机作为一些核心服务的存储。当前这台机开启了nfs服务作为存储服务。因此，我们在使用配置pv的时候，直接使用nfs来作pv。


### 声明PersistentVolume

{% codeblock kestrel-cloud-center-pv.yml lang:yaml %}

apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-kestrel-cloud-mysql-pv
  namespace: kestrel-cloud-center
  labels:
    pv: nfs-kestrel-cloud-mysql-pv
spec:
  capacity:
    storage: 3Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 192.168.10.50
    path: "/data1/nfs/pv/kestrel-cloud-center/mysql"

{% endcodeblock %}

### 声明PersistentVolumeClaim

{% codeblock kestrel-cloud-center-pvc.yml lang:yaml %}

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-kestrel-cloud-mysql-pvc
  namespace: kestrel-cloud-center
spec:
  storageClassName: ""
  resources:
    requests:
      storage: 3Gi
  accessModes:
    - ReadWriteMany
  selector:
    matchLabels:
      pv: nfs-kestrel-cloud-mysql-pv


{% endcodeblock %}

 
