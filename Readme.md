# Strivly orchestrator setup

1. Clone the project:
```
git clone https://github.com/bendaamerahm/my_orchestrator.git
```
```
cd my_orchestrator
```

2. install (pre-configuration)

```
sudo ./install
```

3. create deployment example

```
sudo cli deployment:create --name test --image nginx --replicas 2 --label role=web
```

4. create service example

```
sudo cli service:create --name testService --selector role=web
```

5. create ingress example

```
sudo cli ingress:create --name myIngress --host kubecity.co --backends "/path1=service1,/path2=service1,/path3=service2"
```

6. test

```
curl -s "http://localhost:80"  
```
#TODO
include actions.sh and utils.sh files in worker, manager and service for more readability