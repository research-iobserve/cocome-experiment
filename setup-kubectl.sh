#!/bin/bash

export CLUSTER_NICK=nc05

kubectl config set-cluster $CLUSTER_NICK --server=http://nc05:8080 --kubeconfig=$HOME/.kube/config

# end
