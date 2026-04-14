#!/bin/bash
WZ_MANAGER="172.16.5.20"
CT_IDS="102 103 104 105 106 108 109 111"

for CTID in $CT_IDS; do
    echo "=== Installing Wazuh agent on CT $CTID ==="
    pct exec $CTID -- bash -c "
        apt update && apt install -y lsb-release curl
        curl -s https://packages.wazuh.com/4.x/wazuh-install.sh | bash -s -- -a -i agent -s $WZ_MANAGER
    "
    if [ $? -eq 0 ]; then
        echo "✅ CT $CTID installation successful."
    else
        echo "❌ CT $CTID installation failed."
    fi
done
