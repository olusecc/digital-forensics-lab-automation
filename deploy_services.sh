#!/bin/bash
# Digital Forensics Lab - Quick Service Deployment
# Deploys ELK Stack and MISP with updated configurations

echo "🚀 Digital Forensics Lab - Service Deployment"
echo "=============================================="

# Check if we're in the right directory
if [ ! -f "inventory.yml" ]; then
    echo "❌ Error: Must run from digital-forensics-lab-automation directory"
    exit 1
fi

echo "📋 Current Status:"
echo "  ✅ IRIS: Running on https://10.128.0.19:443"
echo "  ✅ Jenkins: Running on http://10.128.0.20:8080"  
echo "  ✅ SSH Connectivity: Working with cluster_key"
echo "  ❌ ELK Stack: Not deployed"
echo "  ❌ MISP: Not deployed"
echo ""

echo "🔧 Deploying ELK Stack..."
ansible-playbook -i inventory.yml playbooks/elk-stack.yml -v

if [ $? -eq 0 ]; then
    echo "✅ ELK Stack deployment completed"
else
    echo "❌ ELK Stack deployment failed"
    echo "💡 Check logs above for errors"
fi

echo ""
echo "🔧 Deploying MISP..."
ansible-playbook -i inventory.yml playbooks/misp.yml -v

if [ $? -eq 0 ]; then
    echo "✅ MISP deployment completed"
else
    echo "❌ MISP deployment failed"
    echo "💡 Check logs above for errors"
fi

echo ""
echo "🧪 Running connectivity test..."
cd files/integration-scripts
python3 test_connectivity.py

echo ""
echo "📝 Next Steps:"
echo "  1. Test IRIS login: https://10.128.0.19:443 (admin/password from iris logs)"
echo "  2. Configure MISP: http://10.128.0.19:80"
echo "  3. Access Kibana: http://10.128.0.19:5601"
echo "  4. Test Jenkins jobs with updated IP configurations"
echo "  5. Verify integration scripts with new lab_config.py"
