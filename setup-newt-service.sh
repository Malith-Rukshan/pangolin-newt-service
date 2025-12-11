#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Pangolin Newt Systemd Service Setup  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Error: Please run as root or with sudo${NC}"
    echo -e "${YELLOW}   Usage: sudo bash setup-newt-service.sh${NC}"
    exit 1
fi

# Check if newt binary exists
if [ ! -f "/usr/local/bin/newt" ]; then
    echo -e "${RED}❌ Error: Newt binary not found at /usr/local/bin/newt${NC}"
    echo ""
    echo -e "${YELLOW}Please install Newt first using Pangolin's installer script.${NC}"
    echo -e "${YELLOW}Visit: https://docs.pangolin.net${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Newt binary found${NC}"
echo ""

# Get Pangolin command from user
echo -e "${YELLOW}Paste your Pangolin Newt command and press Enter:${NC}"
echo -e "${BLUE}Example:${NC}"
echo "  newt --id b87pbof72mk98nc --secret 6kwq2g92... --endpoint https://mydomain.com --accept-clients"
echo ""
read -r PANGOLIN_CMD

# Validate input
if [[ ! "$PANGOLIN_CMD" =~ "newt" ]] || [[ ! "$PANGOLIN_CMD" =~ "--id" ]]; then
    echo -e "${RED}❌ Error: Invalid command format${NC}"
    echo -e "${YELLOW}   Command must contain 'newt' and '--id'${NC}"
    exit 1
fi

# Extract parameters
NEWT_ID=$(echo "$PANGOLIN_CMD" | grep -oP '(?<=--id )\S+')
NEWT_SECRET=$(echo "$PANGOLIN_CMD" | grep -oP '(?<=--secret )\S+')
NEWT_ENDPOINT=$(echo "$PANGOLIN_CMD" | grep -oP '(?<=--endpoint )\S+')

# Extract all additional flags (like --accept-clients, --log-level, etc.)
EXTRA_FLAGS=$(echo "$PANGOLIN_CMD" | sed 's/.*--endpoint [^ ]*//' | xargs)

# Validate extracted values
if [ -z "$NEWT_ID" ] || [ -z "$NEWT_SECRET" ] || [ -z "$NEWT_ENDPOINT" ]; then
    echo -e "${RED}❌ Error: Could not extract ID, secret, or endpoint${NC}"
    echo -e "${YELLOW}   Please check your command format${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Configuration extracted successfully:${NC}"
echo -e "  ${BLUE}ID:${NC}       $NEWT_ID"
echo -e "  ${BLUE}Endpoint:${NC} $NEWT_ENDPOINT"
[ -n "$EXTRA_FLAGS" ] && echo -e "  ${BLUE}Flags:${NC}    $EXTRA_FLAGS"
echo ""

# Build ExecStart command
EXEC_START="/usr/local/bin/newt --id $NEWT_ID --secret $NEWT_SECRET --endpoint $NEWT_ENDPOINT"
[ -n "$EXTRA_FLAGS" ] && EXEC_START="$EXEC_START $EXTRA_FLAGS"

# Stop existing service if running
if systemctl is-active --quiet newt.service; then
    echo -e "${YELLOW}⚠ Stopping existing Newt service...${NC}"
    systemctl stop newt.service
fi

# Create systemd service
echo -e "${YELLOW}Creating systemd service file...${NC}"

cat > /etc/systemd/system/newt.service <<EOF
[Unit]
Description=Newt - Pangolin Tunnel Client
After=network.target

[Service]
ExecStart=$EXEC_START
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✓ Service file created at /etc/systemd/system/newt.service${NC}"

# Reload systemd and start service
echo -e "${YELLOW}Enabling and starting service...${NC}"
systemctl daemon-reload
systemctl enable newt.service
systemctl start newt.service

# Wait a moment for service to start
sleep 2

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✓ Installation Complete!          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

# Show service status
echo -e "${BLUE}Service Status:${NC}"
systemctl status newt.service --no-pager -l || true
echo ""

echo -e "${YELLOW}Useful Commands:${NC}"
echo -e "  ${BLUE}View logs:${NC}     sudo journalctl -u newt.service -f"
echo -e "  ${BLUE}Restart:${NC}       sudo systemctl restart newt.service"
echo -e "  ${BLUE}Stop:${NC}          sudo systemctl stop newt.service"
echo -e "  ${BLUE}Check status:${NC}  sudo systemctl status newt.service"
echo ""
echo -e "${GREEN}Newt is now running as a background service!${NC}"
echo ""
