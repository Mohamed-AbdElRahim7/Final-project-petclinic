#!/bin/bash
# ============================================
# Kubernetes Cluster Health Check Script
# Usage: ./healthcheck.sh
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Kubernetes Cluster Health Check${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if kubectl is available
echo -e "${BLUE}?? Checking kubectl...${NC}"
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}? kubectl not found${NC}"
    exit 1
fi
echo -e "${GREEN}? kubectl found${NC}"
echo ""

# Check cluster connectivity
echo -e "${BLUE}?? Testing cluster connectivity...${NC}"
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}? Cluster is reachable${NC}"
    kubectl cluster-info | grep -E "Kubernetes control plane|CoreDNS"
else
    echo -e "${RED}? Cannot connect to cluster${NC}"
    exit 1
fi
echo ""

# Check nodes status
echo -e "${BLUE}???  Checking nodes status...${NC}"
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || true)
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" | wc -l)

echo "Total nodes: $NODE_COUNT"
echo -e "${GREEN}Ready: $READY_COUNT${NC}"

if [ $NOT_READY -gt 0 ]; then
    echo -e "${RED}Not Ready: $NOT_READY${NC}"
    kubectl get nodes | grep -v " Ready"
    echo ""
else
    echo -e "${GREEN}? All nodes are Ready${NC}"
fi

# Display nodes
kubectl get nodes -o wide
echo ""

# Check system pods
echo -e "${BLUE}?? Checking system pods...${NC}"
SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || true)
FAILED_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -vE "Running|Completed" | wc -l)

echo "Total system pods: $SYSTEM_PODS"
echo -e "${GREEN}Running: $RUNNING_PODS${NC}"

if [ $FAILED_PODS -gt 0 ]; then
    echo -e "${RED}Failed/Pending: $FAILED_PODS${NC}"
    kubectl get pods -n kube-system | grep -vE "Running|Completed|NAME"
else
    echo -e "${GREEN}? All system pods are Running${NC}"
fi
echo ""

# Check component status
echo -e "${BLUE}?? Checking component health...${NC}"
kubectl get --raw='/readyz?verbose' 2>/dev/null && echo -e "${GREEN}? API server is healthy${NC}" || echo -e "${YELLOW}??  Readiness check not available${NC}"
echo ""

# Check namespaces
echo -e "${BLUE}?? Checking namespaces...${NC}"
kubectl get namespaces
echo ""

# Check CNI (Calico)
echo -e "${BLUE}?? Checking CNI (Calico)...${NC}"
CALICO_PODS=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | wc -l)
CALICO_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | grep -c "Running" || true)

if [ $CALICO_PODS -gt 0 ]; then
    if [ $CALICO_PODS -eq $CALICO_RUNNING ]; then
        echo -e "${GREEN}? Calico CNI is healthy ($CALICO_RUNNING/$CALICO_PODS pods running)${NC}"
    else
        echo -e "${YELLOW}??  Calico pods: $CALICO_RUNNING/$CALICO_PODS running${NC}"
        kubectl get pods -n kube-system -l k8s-app=calico-node
    fi
else
    echo -e "${RED}? Calico not found${NC}"
fi
echo ""

# Check CoreDNS
echo -e "${BLUE}?? Checking CoreDNS...${NC}"
COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l)
COREDNS_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running" || true)

if [ $COREDNS_PODS -gt 0 ]; then
    if [ $COREDNS_PODS -eq $COREDNS_RUNNING ]; then
        echo -e "${GREEN}? CoreDNS is healthy ($COREDNS_RUNNING/$COREDNS_PODS pods running)${NC}"
    else
        echo -e "${YELLOW}??  CoreDNS pods: $COREDNS_RUNNING/$COREDNS_PODS running${NC}"
        kubectl get pods -n kube-system -l k8s-app=kube-dns
    fi
else
    echo -e "${RED}? CoreDNS not found${NC}"
fi
echo ""

# Check Ingress Controller
echo -e "${BLUE}?? Checking Ingress Controller...${NC}"
if kubectl get namespace ingress-nginx &> /dev/null; then
    INGRESS_PODS=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | wc -l)
    INGRESS_RUNNING=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | grep -c "Running" || true)
    
    if [ $INGRESS_PODS -eq $INGRESS_RUNNING ]; then
        echo -e "${GREEN}? Ingress Controller is healthy ($INGRESS_RUNNING/$INGRESS_PODS pods running)${NC}"
        
        # Get LoadBalancer endpoint
        LB_ENDPOINT=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$LB_ENDPOINT" ]; then
            echo -e "${GREEN}   LoadBalancer: $LB_ENDPOINT${NC}"
        fi
    else
        echo -e "${YELLOW}??  Ingress pods: $INGRESS_RUNNING/$INGRESS_PODS running${NC}"
        kubectl get pods -n ingress-nginx
    fi
else
    echo -e "${YELLOW}??  Ingress Controller not installed${NC}"
fi
echo ""

# Check resource usage
echo -e "${BLUE}?? Resource usage summary...${NC}"
if kubectl top nodes &> /dev/null; then
    kubectl top nodes
else
    echo -e "${YELLOW}??  Metrics server not available${NC}"
fi
echo ""

# Check persistent volumes
echo -e "${BLUE}?? Checking persistent volumes...${NC}"
PV_COUNT=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
if [ $PV_COUNT -gt 0 ]; then
    kubectl get pv
else
    echo -e "${YELLOW}??  No persistent volumes found${NC}"
fi
echo ""

# Check services
echo -e "${BLUE}?? Checking services...${NC}"
kubectl get svc --all-namespaces | head -10
echo ""

# Final summary
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Health Check Summary${NC}"
echo -e "${BLUE}============================================${NC}"

EXIT_CODE=0

if [ $NOT_READY -eq 0 ] && [ $FAILED_PODS -eq 0 ]; then
    echo -e "${GREEN}? Cluster is HEALTHY${NC}"
    echo -e "${GREEN}   • All nodes: Ready${NC}"
    echo -e "${GREEN}   • All system pods: Running${NC}"
    echo -e "${GREEN}   • CNI: Operational${NC}"
    echo -e "${GREEN}   • DNS: Operational${NC}"
else
    echo -e "${YELLOW}??  Cluster has issues:${NC}"
    [ $NOT_READY -gt 0 ] && echo -e "${YELLOW}   • $NOT_READY nodes not ready${NC}"
    [ $FAILED_PODS -gt 0 ] && echo -e "${YELLOW}   • $FAILED_PODS system pods failed${NC}"
    EXIT_CODE=1
fi

echo ""
echo -e "${BLUE}============================================${NC}"

exit $EXIT_CODE