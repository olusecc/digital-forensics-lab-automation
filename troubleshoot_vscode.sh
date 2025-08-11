#!/bin/bash

# VS Code Remote SSH Troubleshooting and Configuration Script
# Prevents and fixes common VS Code Remote SSH connection issues

set -e

echo "🔍 VS Code Remote SSH Troubleshooting & Prevention"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    if [ "$2" = "OK" ]; then
        echo -e "${GREEN}✅ $1${NC}"
    elif [ "$2" = "WARN" ]; then
        echo -e "${YELLOW}⚠️  $1${NC}"
    elif [ "$2" = "INFO" ]; then
        echo -e "${BLUE}ℹ️  $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
    fi
}

# Function to check VS Code extensions
check_vscode_extensions() {
    echo -e "${BLUE}📦 Checking VS Code Extensions...${NC}"
    
    if command -v code >/dev/null 2>&1; then
        # Check if Remote SSH extension is installed
        if code --list-extensions | grep -q "ms-vscode-remote.remote-ssh"; then
            print_status "Remote SSH extension installed" "OK"
        else
            print_status "Remote SSH extension NOT installed" "FAIL"
            echo "   Run: code --install-extension ms-vscode-remote.remote-ssh"
        fi
        
        # Check if Remote SSH Editing extension is installed (helpful)
        if code --list-extensions | grep -q "ms-vscode-remote.remote-ssh-edit"; then
            print_status "Remote SSH Editing extension installed" "OK"
        else
            print_status "Remote SSH Editing extension not installed (optional)" "WARN"
            echo "   Run: code --install-extension ms-vscode-remote.remote-ssh-edit"
        fi
    else
        print_status "VS Code 'code' command not available" "WARN"
        echo "   Make sure VS Code is properly installed and 'code' command is in PATH"
    fi
}

# Function to validate SSH configuration
validate_ssh_config() {
    echo -e "${BLUE}🔑 Validating SSH Configuration...${NC}"
    
    for alias in formgt-lab fortools-lab formie-lab; do
        echo "  Testing $alias:"
        
        # Test basic connection
        if timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes $alias "echo 'Connection OK'" 2>/dev/null | grep -q "Connection OK"; then
            print_status "    SSH connection working" "OK"
            
            # Test if user has proper shell access
            SHELL_TEST=$(ssh $alias "echo \$SHELL" 2>/dev/null)
            if [[ "$SHELL_TEST" == *"bash"* ]]; then
                print_status "    Bash shell available" "OK"
            else
                print_status "    Shell: $SHELL_TEST (may cause issues)" "WARN"
            fi
            
            # Test if home directory is accessible
            if ssh $alias "test -w \$HOME && echo 'writable'" 2>/dev/null | grep -q "writable"; then
                print_status "    Home directory writable" "OK"
            else
                print_status "    Home directory not writable" "FAIL"
            fi
            
        else
            print_status "    SSH connection failed" "FAIL"
        fi
    done
}

# Function to check VS Code SSH known issues
check_vscode_ssh_issues() {
    echo -e "${BLUE}🔍 Checking for Common VS Code SSH Issues...${NC}"
    
    # Check if VS Code remote host key files exist and are problematic
    VSCODE_SSH_DIR="$HOME/.vscode-server"
    if [ -d "$VSCODE_SSH_DIR" ]; then
        print_status "VS Code server directory exists" "OK"
        
        # Check for corrupted installations
        for alias in formgt-lab fortools-lab formie-lab; do
            IP=$(ssh $alias "curl -s ifconfig.me" 2>/dev/null || echo "unknown")
            if ssh $alias "ls ~/.vscode-server/bin/ 2>/dev/null" | grep -q "."; then
                print_status "    VS Code server installed on $alias" "OK"
            else
                print_status "    VS Code server not installed on $alias" "INFO"
            fi
        done
    else
        print_status "VS Code server directory not found (first-time setup)" "INFO"
    fi
    
    # Check SSH agent
    if ssh-add -l >/dev/null 2>&1; then
        print_status "SSH agent running with keys loaded" "OK"
    else
        print_status "SSH agent not running or no keys loaded" "WARN"
        echo "   Consider running: ssh-add ~/.ssh/gcp_olusec"
    fi
    
    # Check for SSH multiplexing issues
    if grep -q "ControlMaster" ~/.ssh/config 2>/dev/null; then
        print_status "SSH ControlMaster found (may cause VS Code issues)" "WARN"
        echo "   Consider disabling ControlMaster for VS Code hosts"
    else
        print_status "No SSH ControlMaster conflicts" "OK"
    fi
}

# Function to fix VS Code SSH configuration
fix_vscode_ssh_config() {
    echo -e "${BLUE}🔧 Optimizing SSH Config for VS Code...${NC}"
    
    # Backup current SSH config
    cp ~/.ssh/config ~/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)
    print_status "SSH config backed up" "OK"
    
    # Create VS Code optimized SSH config
    cat > ~/.ssh/config << 'EOF'
# VS Code Remote SSH Optimized Configuration
# Generated by VS Code troubleshooting script

# Lab VM Aliases - Optimized for VS Code Remote SSH
Host formgt-lab
    HostName 34.136.254.74
    User formgt
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    # VS Code specific optimizations
    RequestTTY no
    RemoteCommand none
    # Disable problematic features
    ControlMaster no
    ControlPath none

Host fortools-lab
    HostName 34.172.7.74
    User fortools
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    # VS Code specific optimizations
    RequestTTY no
    RemoteCommand none
    # Disable problematic features
    ControlMaster no
    ControlPath none

Host formie-lab
    HostName 34.123.164.154
    User formie
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    # VS Code specific optimizations
    RequestTTY no
    RemoteCommand none
    # Disable problematic features
    ControlMaster no
    ControlPath none

# Backup direct IP access (fallback)
Host formgt-direct
    HostName 34.136.254.74
    User formgt
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes

Host fortools-direct
    HostName 34.172.7.74
    User fortools
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes

Host formie-direct
    HostName 34.123.164.154
    User formie
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
EOF

    print_status "SSH config optimized for VS Code" "OK"
}

# Function to clean VS Code remote installations
clean_vscode_remote() {
    echo -e "${BLUE}🧹 Cleaning VS Code Remote Installations...${NC}"
    
    for alias in formgt-lab fortools-lab formie-lab; do
        echo "  Cleaning VS Code server on $alias..."
        ssh $alias "rm -rf ~/.vscode-server ~/.vscode-server-insiders" 2>/dev/null || true
        print_status "    Cleaned VS Code server on $alias" "OK"
    done
    
    # Clean local VS Code remote cache
    if [ -d "$HOME/.vscode/extensions" ]; then
        find "$HOME/.vscode/extensions" -name "*remote-ssh*" -type d -exec rm -rf {} + 2>/dev/null || true
        print_status "Local VS Code remote cache cleaned" "OK"
    fi
}

# Function to install required VS Code extensions
install_vscode_extensions() {
    echo -e "${BLUE}📦 Installing Required VS Code Extensions...${NC}"
    
    if command -v code >/dev/null 2>&1; then
        # Install Remote SSH extension
        code --install-extension ms-vscode-remote.remote-ssh
        print_status "Remote SSH extension installed" "OK"
        
        # Install helpful related extensions
        code --install-extension ms-vscode-remote.remote-ssh-edit
        print_status "Remote SSH Edit extension installed" "OK"
        
        code --install-extension ms-vscode.remote-explorer
        print_status "Remote Explorer extension installed" "OK"
    else
        print_status "VS Code not available for extension installation" "WARN"
    fi
}

# Function to create VS Code troubleshooting guide
create_troubleshooting_guide() {
    cat > VS_CODE_TROUBLESHOOTING.md << 'EOF'
# VS Code Remote SSH Troubleshooting Guide

## Quick Fixes

### 1. Connection Timeout or Hangs
```bash
# Clear VS Code remote installations
./troubleshoot_vscode.sh --clean

# Restart SSH connection
ssh-keygen -R <vm-ip>
ssh formgt-lab  # Test connection
```

### 2. "Could not establish connection" Error
```bash
# Check SSH config syntax
ssh -F ~/.ssh/config -T formgt-lab

# Verify VS Code can use the connection
ssh -o BatchMode=yes formgt-lab "echo 'VS Code test'"
```

### 3. Authentication Issues
```bash
# Ensure SSH key is loaded
ssh-add ~/.ssh/gcp_olusec

# Test with verbose SSH
ssh -v formgt-lab
```

### 4. Extensions Won't Install Remotely
```bash
# Clear remote extensions
ssh formgt-lab "rm -rf ~/.vscode-server"

# Restart VS Code and reconnect
```

## VS Code Remote SSH Setup Steps

1. **Install Extensions**:
   - Remote - SSH
   - Remote - SSH: Editing Configuration Files
   - Remote Explorer

2. **Connect to Remote Host**:
   - Open Command Palette (Ctrl+Shift+P)
   - Type "Remote-SSH: Connect to Host"
   - Select from: `formgt-lab`, `fortools-lab`, `formie-lab`

3. **First Connection**:
   - VS Code will install the server automatically
   - May take 2-3 minutes on first connection
   - Select "Linux" as the platform

4. **If Connection Fails**:
   - Run: `./troubleshoot_vscode.sh`
   - Check SSH connection: `ssh formgt-lab`
   - Try direct IP connection as fallback

## Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| "SSH connection timed out" | Run `./update_config.sh` to refresh IPs |
| "Could not establish connection" | Clear `.vscode-server` directory on remote |
| "Authentication failed" | Check SSH key with `ssh-add -l` |
| "Remote host identification has changed" | Run `ssh-keygen -R <ip>` |
| VS Code hangs on "Opening Remote..." | Kill VS Code, run troubleshoot script |

## Prevention

- Run `./health_check.sh` weekly
- Run `./update_config.sh` after VM restarts
- Keep VS Code and extensions updated
- Use aliases (`formgt-lab`) instead of direct IPs
EOF

    print_status "Created VS_CODE_TROUBLESHOOTING.md" "OK"
}

# Main execution
main() {
    case "${1:-}" in
        --clean)
            clean_vscode_remote
            ;;
        --fix)
            fix_vscode_ssh_config
            install_vscode_extensions
            ;;
        --check)
            check_vscode_extensions
            validate_ssh_config
            check_vscode_ssh_issues
            ;;
        *)
            echo "🚀 Running Complete VS Code SSH Troubleshooting..."
            echo ""
            
            check_vscode_extensions
            echo ""
            validate_ssh_config
            echo ""
            check_vscode_ssh_issues
            echo ""
            
            read -p "Do you want to apply fixes? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo ""
                fix_vscode_ssh_config
                echo ""
                install_vscode_extensions
                echo ""
                clean_vscode_remote
            fi
            
            echo ""
            create_troubleshooting_guide
            
            echo ""
            echo "🎯 VS Code Remote SSH Troubleshooting Complete!"
            echo ""
            print_status "Next Steps:" "INFO"
            echo "1. Restart VS Code completely"
            echo "2. Open Command Palette (Ctrl+Shift+P)"
            echo "3. Run 'Remote-SSH: Connect to Host'"
            echo "4. Select 'formgt-lab', 'fortools-lab', or 'formie-lab'"
            echo "5. If issues persist, check VS_CODE_TROUBLESHOOTING.md"
            echo ""
            echo "Quick test: Try connecting via Command Palette now!"
            ;;
    esac
}

# Script options
echo "Usage: $0 [--clean|--fix|--check]"
echo "  --clean: Clean VS Code remote installations"
echo "  --fix:   Apply configuration fixes"
echo "  --check: Check configuration only"
echo "  (no args): Run interactive troubleshooting"
echo ""

main "$@"
