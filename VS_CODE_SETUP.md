# VS Code Remote SSH Setup Guide

## Prerequisites

1. **Install VS Code Remote SSH Extension**:
   - Open VS Code
   - Go to Extensions (Ctrl+Shift+X)
   - Search for "Remote - SSH"
   - Install the extension by Microsoft

## Quick Setup

✅ **SSH configuration has been cleaned and optimized for VS Code!**

Your SSH config has been automatically configured and tested. Current VM connections:

- `formgt-lab` - Connect to formgt VM (34.136.254.74) ✅ Working
- `fortools-lab` - Connect to fortools VM (34.172.7.74) ✅ Working  
- `formie-lab` - Connect to formie VM (34.123.164.154) ✅ Working

**All connections tested and verified!**

## VS Code Connection Steps

1. **Open Command Palette** (Ctrl+Shift+P)
2. **Type**: `Remote-SSH: Connect to Host...`
3. **Select one of**:
   - `formgt-lab`
   - `fortools-lab`
   - `formie-lab`
4. **Select platform**: `Linux`
5. **Wait for connection** and VS Code server installation

## Alternative: Manual Connection

If the above doesn't work, you can manually add a connection:

1. **Command Palette** → `Remote-SSH: Open SSH Configuration File...`
2. **Select**: `~/.ssh/config`
3. **Verify entries exist** (they should already be there):

```ssh-config
Host formgt-lab
    HostName 34.136.254.74
    User formgt
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no
```

## Troubleshooting

### Issue: "Could not establish connection"
- **Solution**: Try connecting via terminal first: `ssh formgt-lab`
- **If terminal works**: Restart VS Code and try again
- **If terminal fails**: Run `./setup_ssh_config.sh` again

### Issue: "Host key verification failed"
- **Solution**: Run `ssh-keygen -R <VM_IP>` to remove old host keys
- **Example**: `ssh-keygen -R 34.136.254.74`

### Issue: "Permission denied (publickey)"
- **Check SSH key**: `ls -la ~/.ssh/gcp_olusec*`
- **Test key**: `ssh -i ~/.ssh/gcp_olusec formgt@34.136.254.74`
- **Regenerate if needed**: Contact admin to add your public key

### Issue: VS Code asks for password
- **Ensure**: `IdentitiesOnly yes` is in SSH config
- **Check**: SSH key permissions `chmod 600 ~/.ssh/gcp_olusec`

## Testing Connections

Test each connection before using VS Code:

```bash
# Test all connections
ssh formgt-lab "echo 'formgt connection works'"
ssh fortools-lab "echo 'fortools connection works'"  
ssh formie-lab "echo 'formie connection works'"
```

## VM-to-VM SSH (once connected via VS Code)

From inside any VM, you can SSH to other VMs:

```bash
# Use internal hostnames
ssh fortools@fortools.lab.internal
ssh formie@formie.lab.internal
ssh formgt@formgt.lab.internal
```

## Useful VS Code Remote Features

1. **File Explorer**: Browse VM files directly
2. **Terminal**: Integrated terminal on the remote VM
3. **Extensions**: Install extensions on the remote VM
4. **Port Forwarding**: Forward ports from VM to local machine
5. **File Sync**: Edit files that sync automatically

## Quick Reference

Current VM Details:
- **formgt VM**: 34.136.254.74 (60GB, 2 vCPU, 4GB RAM)
- **fortools VM**: 34.173.123.123 (80GB, 2 vCPU, 4GB RAM)  
- **formie VM**: 34.123.164.154 (100GB, 4 vCPU, 8GB RAM)

SSH Config Aliases:
- `formgt-lab` → formgt@34.136.254.74
- `fortools-lab` → fortools@34.173.123.123
- `formie-lab` → formie@34.123.164.154
