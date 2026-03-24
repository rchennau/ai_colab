# WSL Ubuntu Setup Guide for ai-colab

This guide provides complete setup instructions for running ai-colab on WSL2 Ubuntu with optimal terminal experience.

## 🎯 Recommended Setup

### Hardware Requirements
- **Windows 10/11** with WSL2 support
- **Minimum 8GB RAM** (16GB recommended for multi-agent workflows)
- **SSD storage** for best performance

### Software Stack
1. **WSL2** (Windows Subsystem for Linux)
2. **Ubuntu 22.04 LTS** or newer
3. **Windows Terminal** (from Microsoft Store)
4. **tmux 3.0+** for multi-pane dashboard

---

## 📋 Step-by-Step Installation

### 1. Enable WSL2

Open PowerShell as Administrator and run:

```powershell
# Enable WSL
wsl --install

# Set WSL2 as default
wsl --set-default-version 2

# Install Ubuntu (if not already done)
wsl --install -d Ubuntu
```

Restart your computer if prompted.

### 2. Install Windows Terminal

**Option A: Microsoft Store (Recommended)**
- Open Microsoft Store
- Search for "Windows Terminal"
- Click Install

**Option B: Winget**
```powershell
winget install --id Microsoft.WindowsTerminal
```

### 3. Configure Windows Terminal

Open Windows Terminal settings (Ctrl+,) and update `settings.json`:

```json
{
    "profiles": {
        "defaults": {
            "font": {
                "face": "Cascadia Code PL",
                "size": 11
            },
            "colorScheme": "One Half Dark",
            "cursorShape": "bar",
            "scrollbarState": "visible",
            "antialiasingMode": "cleartype",
            "padding": "8, 8, 8, 8"
        }
    },
    "defaultProfile": "{your-ubuntu-profile-guid}"
}
```

### 4. Install Ubuntu Dependencies

Open Ubuntu in Windows Terminal and run:

```bash
# Update package list
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y \
    tmux \
    git \
    curl \
    wget \
    build-essential \
    sqlite3 \
    python3 \
    python3-pip \
    nodejs \
    npm
```

### 5. Install ai-colab

```bash
# Clone the repository
cd ~
git clone https://github.com/rchennau/ai_colab.git
cd ai_colab

# Run the installer
./install.sh
```

The installer will:
- Detect WSL environment automatically
- Configure Windows Terminal optimizations
- Set up clipboard integration
- Install all LLM CLI tools

### 6. Configure tmux for Windows Terminal

During installation, accept the prompt to install the Windows Terminal tmux configuration:

```bash
# Or manually copy the config
cp config/tmux.windows-terminal.conf ~/.tmux.conf
```

---

## 🔧 WSL-Specific Optimizations

### Clipboard Integration

ai-colab automatically configures clipboard integration between WSL and Windows:

**Copy from tmux to Windows:**
- In tmux: `Prefix + y` (copies to Windows clipboard)
- Or: `tmux save-buffer - | clip.exe`

**Paste from Windows to WSL:**
- Use `Ctrl+Shift+V` in Windows Terminal
- Or middle-click if mouse mode is enabled

### Windows Interop

Access Windows executables directly from WSL:

```bash
# Open Windows Notepad
notepad.exe file.txt

# Open Windows Explorer in current directory
explorer.exe .

# Run PowerShell commands
powershell.exe "Get-Process"
```

### Path Translation

Convert between WSL and Windows paths:

```bash
# WSL path to Windows path
wslpath -w /home/user/ai_colab
# Output: \\wsl$\Ubuntu\home\user\ai_colab

# Windows path to WSL path
wslpath '/mnt/c/Users/user'
# Output: /mnt/c/Users/user
```

### Performance Tips

**1. Store Project Files in WSL Filesystem**
```bash
# ✓ GOOD - Fast performance
~/ai_colab/projects/

# ✗ AVOID - Slow performance
/mnt/c/Users/user/ai_colab/projects/
```

**2. Disable Windows Defender Real-Time Protection for WSL**
Add this to Windows Security settings:
- Settings → Update & Security → Windows Security
- Virus & threat protection → Manage settings
- Exclusions → Add exclusion → Folder
- Add: `\\wsl$\Ubuntu\home\youruser`

**3. Increase WSL Memory (if needed)**
Create `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
memory=8GB
processors=4
swap=4GB
localhostForwarding=true
```

Then restart WSL:
```powershell
wsl --shutdown
```

---

## 🎨 Terminal Customization

### Recommended Fonts

Install these fonts in Windows for best experience:

1. **Cascadia Code PL** (comes with Windows Terminal)
2. **JetBrains Mono Nerd Font**
3. **Fira Code Nerd Font**

Download Nerd Fonts: https://www.nerdfonts.com/font-downloads

### Windows Terminal Color Schemes

Add these to `settings.json`:

```json
"schemes": [
    {
        "name": "ai-colab Dark",
        "background": "#1E1E1E",
        "foreground": "#D4D4D4",
        "cursorColor": "#81A1C1",
        "selectionBackground": "#3E4451",
        "black": "#3A3A3A",
        "red": "#E06C75",
        "green": "#98C379",
        "yellow": "#E5C07B",
        "blue": "#61AFEF",
        "purple": "#C678DD",
        "cyan": "#56B6C2",
        "white": "#ABB2BF",
        "brightBlack": "#5C6370",
        "brightRed": "#E06C75",
        "brightGreen": "#98C379",
        "brightYellow": "#E5C07B",
        "brightBlue": "#61AFEF",
        "brightPurple": "#C678DD",
        "brightCyan": "#56B6C2",
        "brightWhite": "#FFFFFF"
    }
]
```

---

## 🚀 Using ai-colab in WSL

### Launch the Dashboard

```bash
cd ~/ai_colab
./launch.sh
```

### Terminal-Specific Features

**Windows Terminal detects ai-colab automatically:**
- ✓ True color support enabled
- ✓ Clipboard integration active
- ✓ Unicode symbols supported
- ✓ Mouse support in tmux

### Common Commands

```bash
# Check terminal detection
./scripts/terminal-detect.sh

# Restart tmux server
tmux kill-server
tmux

# Access Windows clipboard
echo "text" | clip.exe

# Open Windows Explorer in project
explorer.exe .
```

---

## 🐛 Troubleshooting

### Issue: tmux display looks corrupted

**Solution:**
```bash
# Clear terminfo cache
rm -rf ~/.terminfo

# Reinstall tmux
sudo apt install --reinstall tmux

# Use the ai-colab config
cp ~/ai_colab/config/tmux.windows-terminal.conf ~/.tmux.conf
```

### Issue: Clipboard not working

**Solution:**
```bash
# Test Windows clipboard
echo "test" | clip.exe

# If fails, restart Windows Terminal
# Check wslu is installed
sudo apt install wslu
```

### Issue: Slow filesystem performance

**Solution:**
- Move project files to WSL filesystem (`~/` not `/mnt/c/`)
- Add Windows Defender exclusion for WSL
- Ensure using WSL2 not WSL1: `wsl --list --verbose`

### Issue: Colors look wrong

**Solution:**
Add to `~/.bashrc`:
```bash
export COLORTERM="truecolor"
export TERM="xterm-256color"
```

### Issue: Can't access Windows network

**Solution:**
```bash
# Access Windows host
ping $(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')

# Or use host.docker.internal
ping host.docker.internal
```

---

## 📊 WSL vs macOS Comparison

| Feature | WSL2 + Windows Terminal | macOS + iTerm2 |
|---------|------------------------|----------------|
| **Performance** | Excellent (native Linux kernel) | Excellent (native Unix) |
| **Color Support** | True color (24-bit) | True color (24-bit) |
| **Font Rendering** | Very Good (ClearType) | Excellent (Quartz) |
| **Clipboard** | Windows integration | macOS integration |
| **File System** | Fast (ext4 in WSL2) | Fast (APFS) |
| **GPU Acceleration** | Limited | Full support |
| **Best For** | Windows users, Linux dev | macOS users, native Unix |

---

## 🔗 Additional Resources

- [WSL2 Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
- [Windows Terminal Documentation](https://docs.microsoft.com/en-us/windows/terminal/)
- [tmux Cheat Sheet](https://tmuxcheatsheet.com/)
- [ai-colab README](../README.md)

---

## 🎯 Quick Reference

```bash
# Terminal detection
./scripts/terminal-detect.sh

# Install with optimizations
./install.sh

# Launch dashboard
./launch.sh

# Copy to Windows clipboard
tmux save-buffer - | clip.exe

# Open in Windows Explorer
explorer.exe .

# Restart WSL (from PowerShell)
wsl --shutdown
```

---

**Happy collaborating from WSL! 🐧🪟**
