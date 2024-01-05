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
apt_check_and_install "jq"   # Used to parse JSON

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

rm -f *.yaml >/dev/null 2>&1

kubectl delete deployment nodeapp >/dev/null 2>&1
kubectl delete deployment nginx >/dev/null 2>&1

kubectl delete service nodeapp-service >/dev/null 2>&1

kubectl delete pod log4j >/dev/null 2>&1
kubectl delete pod nginx >/dev/null 2>&1

kubectl delete ns netdemo >/dev/null 2>&1
kubectl delete service netdemo-service -n netdemo >/dev/null 2>&1
kubectl delete configmaps netdemo-configmap -n netdemo >/dev/null 2>&1
kubectl delete pod netdemo -n netdemo>/dev/null 2>&1

rm -rf cb_demos >/dev/null 2>&1

kubectl delete deployment malware-app >/dev/null 2>&1

#####################################
###        DEMO INTRO             ###
#####################################

demo_intro() {
clear
echo "---"
echo -e "${RED}Carbon Black Cloud Container${NC} can protect:"
echo -e " - Kubernetes onprem"
echo -e " - Kubernetes in public cloud, for example Amazon (EKS), Azure(AKS), or Google(GKE).."
echo -e " - minikube"
echo -e " - microK8s"

# Depending on your customer, you can enable the following lines
echo -e " - OpenShift"
echo -e " - Rancher"

echo -e " - and of course Tanzu."

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
echo -e "Let's check that Carbon Black Container is ${GREEN}running${NC} in this Kubernetes cluster."
echo -e "How to check what pods are running in the Kubernetes cluster?"
pe "kubectl get pods -A"
wait
echo -e ""
echo -e "---"
echo -e "Carbon Black Container is running in it's own NAMESPACE ${GREEN}cbcontainers-dataplane${NC}."
wait
}

#####################################
###        DAEMONSET              ###
#####################################

demo_daemonset() {
clear
echo "---"
echo -e "Carbon Black Container is deployed in each Kubernetes cluster."
echo -e "Carbon Black Container ${GREEN}node agent${NC} is deployed as a ${GREEN}daemonset${NC} in each Kubernetes node."
echo "It means that in a Kubernetes cluster with Carbon Black Container, on each Kubernetes node, a Carbon Black Container agent will run."
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
echo -e "In Carbon Black Container web UI, create a policy to ${RED}BLOCK deployments with no CPU/mem quotas${NC}."
echo -e ""
echo -e "Why a ${RED}minimum${NC} quota?"
p "To be sure the pod will have enough CPU/mem to run correctly."
echo -e "Why a ${RED}maximum${NC} quota?"
p "To be sure the pod will not eat all CPU/mem, because of a bug or a cryptominer virus.."
wait
clear
echo -e "---"
echo -e "We have prepared 2 deployment files, the ${GREEN}GOOD${NC} and the ${RED}BAD${NC} deployment files."
rm *.yaml
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
pe "firefox http://127.0.0.1:30333 2>/dev/null"
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

#Uninstall nodeapp
kubectl delete deployment nodeapp >/dev/null 2>&1
kubectl delete service nodeapp-service >/dev/null 2>&1
}
#####################################
###          EXEC                 ###
#####################################

demo_exec() {
clear
echo "Exec demo"
echo "---"
echo -e "First we will create a nginx deployment, it could be any container image."
pe "kubectl create deployment nginx --image=nginx"

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
echo -e "Modify Carbon Black Container to ${RED}BLOCK --- COMMAND / Exec to container---${NC}"
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
echo "Log4j demo"
echo "---"
echo -e "Modify Carbon Black Container to ${RED}BLOCK --- CONTAINER IMAGES / Critical vulnerabilities ---${NC}"
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

echo "---"
echo -e "Modify Carbon Black Container to ${RED}ALERT --- CONTAINER IMAGES / Critical vulnerabilities ---${NC}"
wait

#In case it was not blocked, delete this log4j pod
kubectl delete pod log4j >/dev/null 2>&1
}

#####################################
###          GO PACKAGE           ###
#####################################

demo_go() {
echo -e "---"
echo -e "Let's scan an old vulnerable container with ${GREEN}GO${NC} packages"
pe "cbctl image scan anchore/syft:v0.20.0"
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
echo -e "In our Kubernetes clusters, we can monitor/alert on ${RED}runtime network malicious activities${NC} such as:"
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

# TODO : Use jq instead, something like
# kubectl get svc/kubernetes -o json | jq .spec.ports[0].port
port=$(kubectl get services -n netdemo --no-headers | sed "s/.*://" | cut -f1 -d"/")

pe "firefox http://127.0.0.1:${port} 2>/dev/null"
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
kubectl delete services nginx >/dev/null 2>&1

echo "---"
echo -e "Modify Carbon Black Container to ${RED}ENFORCE --- Allow PRIVILEGED containers---${NC}"
wait
echo ""
echo -e "Check that CB mutating webhook is ready"
pe "kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io"

echo "---"
echo -e "Let's create a new ${RED}insecure${NC} deployment file (with ${RED}privileges${NC})."
echo ""
echo -e "First we will create a nginx deployment."
pe "kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > temp.yaml"

echo ""
echo -e "Cleanup the deployment file"
pei "grep -v status temp.yaml |grep -v null >nginx.yaml"

echo ""
echo -e "Now, we will add ${RED}privileges${NC} to this deployment"

pei "echo \"        securityContext:\" >> nginx.yaml"
pei "echo \"          privileged: true\" >> nginx.yaml"

echo ""
echo "---"
cat nginx.yaml
wait

echo ""
echo "---"
echo -e "Now, we will deploy this ${RED}insecure${NC} deployment file."
pe "kubectl apply -f nginx.yaml"
wait

echo -e "What is the deployment in production now ?"
pe "kubectl get deployments nginx --output=yaml"
wait

echo -e "---"
echo -e "Let's connect to ${GREEN}nginx${NC}"
pei "kubectl expose deployment nginx --port 80"
pei "kubectl get services"
ip=$(kubectl get services nginx --no-headers  | awk '{print $3}')
pe "firefox http://${ip} 2>/dev/null"
wait
}

demo_malware() {
clear
echo "---"
echo -e "As a developer, I would like to check that a container image doesn't contain a ${RED}malware${NC}."
pe "cbctl image scan xmrig/xmrig"
echo "---"
echo -e "xmrig is a popular ${RED}crypto miner${NC} used on Linux and in Containers."
echo -e "Now let's scan and deploy a fake ${RED}malware${NC}, and see in CBC UI / Container Images / File Reputations."
pe "cbctl image scan octarinesec/public-image-scanning-demo:malware-mixed-files-27-01-2023"
echo "---"
pei "kubectl create deployment --image=octarinesec/public-image-scanning-demo:malware-mixed-files-27-01-2023 malware-app"
wait
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

#Runtime demo - Network
demo_runtime

#Vulnerability management
demo_log4j

# Use this demo for DEV/SEC/OPS only
#demo_quota
# Warning: demo_exec needs demo_quota
#demo_exec

#demo_go

#Hardening / Mutate
demo_enforce

#Malware scan
demo_malware

demo_end

exit 0
