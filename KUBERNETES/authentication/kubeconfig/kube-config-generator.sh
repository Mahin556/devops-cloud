#!/bin/sh

read -p 'Enter the Username : ' name
read -p 'Enter the Group Name : ' group
read -p 'Enter the Namespace Name: ' namespace

export CLIENT=$name
export GROUP=$group
export NAMESPACE=$namespace

echo -e "\nUsername is: ${CLIENT}\nGroup Name is: ${GROUP}\nand Namespace is: ${NAMESPACE}"
echo -e "\nIf you want to proceed with above informaton, type \"yes\" or \"no\": " 
read value

if [ $value == "yes" ]
then
    mkdir ${CLIENT}
    cd ${CLIENT}
    
    #Generate key
    openssl genrsa -out ${CLIENT}.key 2048
    
    #Generate csr
    openssl req -new -key ${CLIENT}.key -subj "/CN=${CLIENT}/O=${GROUP}" -out ${CLIENT}.csr
    
    #CSR to base64
    export CSR_CLIENT=$(cat ${CLIENT}.csr | base64 -w 0)
    
    #Create CSR object file
    curl https://raw.githubusercontent.com/shamimice03/Kubernetes_RBAC/main/CertificateSigningRequest-Template.yaml | sed "s/<name>/${CLIENT}/ ; s/<csr-base64>/${CSR_CLIENT}/" > ${CLIENT}_csr.yaml
   
    #Create CSR object
    kubectl create -f ${CLIENT}_csr.yaml
   
    #Approve CSR 
    kubectl certificate approve ${CLIENT}
    
    #extracting client certificate
    kubectl get csr ${CLIENT} -o jsonpath='{.status.certificate}' | base64 --decode > ${CLIENT}.crt
    
    #CA extraction 
    kubectl config view --raw -o jsonpath='{..cluster.certificate-authority-data}' | base64 --decode > ca.crt
   
    #Set ENV
    export CA_CRT=$(cat ca.crt | base64 -w 0)
    export CONTEXT=$(kubectl config current-context)
    export CLUSTER_ENDPOINT=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="'"$CONTEXT"'")].cluster.server}')
    export USER=${CLIENT}
    export CRT=$(cat ${CLIENT}.crt | base64 -w 0)
    export KEY=$(cat ${CLIENT}.key | base64 -w 0)
    export NAMESPACE=$namespace
    
    #Configure kubeconfig file
    curl https://raw.githubusercontent.com/shamimice03/Kubernetes_RBAC/main/kubeconfig-template.yaml | sed "s#<context>#${CONTEXT}# ;
    s#<cluster-name>#${CONTEXT}# ;
    s#<ca.crt>#${CA_CRT}# ;
    s#<cluster-endpoint>#${CLUSTER_ENDPOINT}# ;
    s#<user-name>#${USER}# ;
    s#<namespace>#${NAMESPACE}# ;
    s#<user.crt>#${CRT}# ; 
    s#<user.key>#${KEY}#" > config

else
    echo -e "See you next time, Good Luck.\n" 
    exit
fi