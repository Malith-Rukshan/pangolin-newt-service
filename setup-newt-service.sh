#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SERVICE_FILE="/etc/systemd/system/newt.service"

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Error: Please run as root or with sudo${NC}"
        echo -e "${YELLOW}   Usage: sudo bash setup-newt-service.sh${NC}"
        exit 1
    fi
}

# Check if newt binary exists
check_newt_binary() {
    if [ ! -f "/usr/local/bin/newt" ]; then
        echo -e "${RED}❌ Error: Newt binary not found at /usr/local/bin/newt${NC}"
        echo ""
        echo -e "${YELLOW}Please install Newt first using Pangolin's installer script.${NC}"
        echo -e "${YELLOW}Visit: https://docs.pangolin.net${NC}"
        exit 1
    fi
}

# Migrate to Newt 1.7.0
migrate_to_1_7_0() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Migrate to Newt 1.7.0              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}❌ Error: Service file not found at $SERVICE_FILE${NC}"
        echo -e "${YELLOW}   Please create a service first${NC}"
        return
    fi

    echo -e "${YELLOW}ℹ  Changes in Newt 1.7.0:${NC}"
    echo -e "   • ${CYAN}--accept-clients${NC} is now ${GREEN}enabled by default${NC}"
    echo -e "   • Use ${CYAN}--disable-clients${NC} to disable client connections"
    echo ""

    # Stop the service
    if systemctl is-active --quiet newt.service; then
        echo -e "${YELLOW}⚠  Stopping Newt service...${NC}"
        systemctl stop newt.service
        echo -e "${GREEN}✓ Service stopped${NC}"
    else
        echo -e "${YELLOW}ℹ  Service is not running${NC}"
    fi

    # Backup current service file
    echo -e "${YELLOW}Creating backup...${NC}"
    cp "$SERVICE_FILE" "${SERVICE_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
    echo -e "${GREEN}✓ Backup created${NC}"

    # Read current ExecStart line
    CURRENT_EXEC=$(grep "^ExecStart=" "$SERVICE_FILE" | sed 's/^ExecStart=//')

    # Remove --accept-clients flag (it's default in 1.7.0)
    NEW_EXEC=$(echo "$CURRENT_EXEC" | sed 's/ --accept-clients//g')

    if [ "$CURRENT_EXEC" != "$NEW_EXEC" ]; then
        echo -e "${YELLOW}Updating service file...${NC}"
        sed -i.tmp "s|^ExecStart=.*|ExecStart=$NEW_EXEC|" "$SERVICE_FILE"
        rm -f "${SERVICE_FILE}.tmp"
        echo -e "${GREEN}✓ Removed --accept-clients flag (now default enabled)${NC}"
    else
        echo -e "${YELLOW}ℹ  No --accept-clients flag found, service file unchanged${NC}"
    fi

    # Reload and restart
    echo -e "${YELLOW}Reloading systemd daemon...${NC}"
    systemctl daemon-reload
    echo -e "${GREEN}✓ Daemon reloaded${NC}"

    echo -e "${YELLOW}Starting Newt service...${NC}"
    systemctl start newt.service
    sleep 2

    if systemctl is-active --quiet newt.service; then
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   ✓ Migration Complete!               ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}Service Status:${NC}"
        systemctl status newt.service --no-pager -l || true
    else
        echo ""
        echo -e "${RED}❌ Error: Service failed to start${NC}"
        echo -e "${YELLOW}   Check logs: sudo journalctl -u newt.service -n 50${NC}"
    fi
}

# Add new service
add_new_service() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      Add New Newt Service              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    # Get Pangolin command from user
    echo -e "${YELLOW}Paste your Pangolin Newt command and press Enter:${NC}"
    echo -e "${BLUE}Example (Newt 1.7.0+):${NC}"
    echo "  newt --id b87pbof72mk98nc --secret 6kwq2g92... --endpoint https://mydomain.com"
    echo ""
    echo -e "${CYAN}Note: ${NC}Client connections are enabled by default in 1.7.0+"
    echo -e "${CYAN}      ${NC}Use ${YELLOW}--disable-clients${NC} if you want to disable them"
    echo ""
    read -r PANGOLIN_CMD </dev/tty

    # Validate input
    if [[ ! "$PANGOLIN_CMD" =~ "newt" ]] || [[ ! "$PANGOLIN_CMD" =~ "--id" ]]; then
        echo -e "${RED}❌ Error: Invalid command format${NC}"
        echo -e "${YELLOW}   Command must contain 'newt' and '--id'${NC}"
        return
    fi

    # Extract parameters
    NEWT_ID=$(echo "$PANGOLIN_CMD" | grep -oP '(?<=--id )\S+')
    NEWT_SECRET=$(echo "$PANGOLIN_CMD" | grep -oP '(?<=--secret )\S+')
    NEWT_ENDPOINT=$(echo "$PANGOLIN_CMD" | grep -oP '(?<=--endpoint )\S+')

    # Extract all additional flags and remove --accept-clients (deprecated in 1.7.0)
    EXTRA_FLAGS=$(echo "$PANGOLIN_CMD" | sed 's/.*--endpoint [^ ]*//' | sed 's/--accept-clients//g' | xargs)

    # Validate extracted values
    if [ -z "$NEWT_ID" ] || [ -z "$NEWT_SECRET" ] || [ -z "$NEWT_ENDPOINT" ]; then
        echo -e "${RED}❌ Error: Could not extract ID, secret, or endpoint${NC}"
        echo -e "${YELLOW}   Please check your command format${NC}"
        return
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
        echo -e "${YELLOW}⚠  Stopping existing Newt service...${NC}"
        systemctl stop newt.service
    fi

    # Create systemd service
    echo -e "${YELLOW}Creating systemd service file...${NC}"

    cat > "$SERVICE_FILE" <<EOF
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

    echo -e "${GREEN}✓ Service file created at $SERVICE_FILE${NC}"

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
}

# Check service status
check_service() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      Newt Service Status               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}❌ Service file not found${NC}"
        echo -e "${YELLOW}   Please create a service first${NC}"
        return
    fi

    systemctl status newt.service --no-pager -l || true
    echo ""

    if systemctl is-active --quiet newt.service; then
        echo -e "${GREEN}✓ Service is running${NC}"
    else
        echo -e "${RED}❌ Service is not running${NC}"
    fi
}

# View service logs
view_logs() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      Newt Service Logs                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Showing last 50 lines (press Ctrl+C to exit)...${NC}"
    echo ""

    journalctl -u newt.service -n 50 -f
}

# Restart service
restart_service() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      Restart Newt Service              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}❌ Service file not found${NC}"
        echo -e "${YELLOW}   Please create a service first${NC}"
        return
    fi

    echo -e "${YELLOW}Restarting Newt service...${NC}"
    systemctl restart newt.service
    sleep 2

    if systemctl is-active --quiet newt.service; then
        echo -e "${GREEN}✓ Service restarted successfully${NC}"
        echo ""
        systemctl status newt.service --no-pager -l || true
    else
        echo -e "${RED}❌ Service failed to restart${NC}"
        echo -e "${YELLOW}   Check logs: sudo journalctl -u newt.service -n 50${NC}"
    fi
}

# Stop service
stop_service() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      Stop Newt Service                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}❌ Service file not found${NC}"
        return
    fi

    if systemctl is-active --quiet newt.service; then
        echo -e "${YELLOW}Stopping Newt service...${NC}"
        systemctl stop newt.service
        echo -e "${GREEN}✓ Service stopped${NC}"
    else
        echo -e "${YELLOW}ℹ  Service is not running${NC}"
    fi
}

# Show main menu
show_menu() {
    clear
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Pangolin Newt Service Manager        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Select an option:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) ${YELLOW}Migrate to Newt 1.7.0${NC}"
    echo -e "     └─ Auto-fix service files for version 1.7.0"
    echo ""
    echo -e "  ${GREEN}2${NC}) ${YELLOW}Add New Service${NC}"
    echo -e "     └─ Create or update Newt service"
    echo ""
    echo -e "  ${GREEN}3${NC}) ${YELLOW}Check Service Status${NC}"
    echo -e "     └─ View current service status"
    echo ""
    echo -e "  ${GREEN}4${NC}) ${YELLOW}View Service Logs${NC}"
    echo -e "     └─ Real-time log monitoring"
    echo ""
    echo -e "  ${GREEN}5${NC}) ${YELLOW}Restart Service${NC}"
    echo -e "     └─ Restart the Newt service"
    echo ""
    echo -e "  ${GREEN}6${NC}) ${YELLOW}Stop Service${NC}"
    echo -e "     └─ Stop the Newt service"
    echo ""
    echo -e "  ${GREEN}0${NC}) ${RED}Exit${NC}"
    echo ""
    echo -ne "${CYAN}Enter your choice [0-6]: ${NC}"
}

# Main loop
main() {
    check_root
    check_newt_binary

    while true; do
        show_menu
        read -r choice </dev/tty

        case $choice in
            1)
                migrate_to_1_7_0
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${NC}"
                read -r </dev/tty
                ;;
            2)
                add_new_service
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${NC}"
                read -r </dev/tty
                ;;
            3)
                check_service
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${NC}"
                read -r </dev/tty
                ;;
            4)
                view_logs
                ;;
            5)
                restart_service
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${NC}"
                read -r </dev/tty
                ;;
            6)
                stop_service
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${NC}"
                read -r </dev/tty
                ;;
            0)
                echo ""
                echo -e "${GREEN}Thank you for using Pangolin Newt Service Manager!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${RED}❌ Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main function
main