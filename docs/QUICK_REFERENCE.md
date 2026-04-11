# ai-colab Terminal Quick Reference

## 🚀 Quick Start

### Global CLI (Recommended)
```bash
# Install ai-colab globally
./install.sh --global

# Start managing any git project
cd ~/my-project
ai-colab
```

### macOS (iTerm2)
```bash
# Install iTerm2
brew install --cask iterm2

# Install ai-colab with optimizations
./install.sh

# Launch dashboard
./launch.sh
```

---

## ⌨️ tmux Key Bindings

| Action | Keys |
|--------|------|
| **Prefix** | `Ctrl-a` (or `Ctrl-b` depending on config) |
| **Focus Mode** | `Prefix + f` (Zoom/Unzoom current pane) |
| **Go to Dashboard**| `Prefix + h` |
| **Go to Fleet** | `Prefix + l` |
| **Reload config** | `Prefix + r` |
| **Split vertical** | `Prefix + \|` |
| **Split horizontal** | `Prefix + -` |
| **Navigate panes** | `Prefix + Arrow Keys` |
| **Resize panes** | `Prefix + H/J/K/L` |
| **Copy to clipboard** | `Prefix + y` |
| **Next window** | `Prefix + n` |
| **Previous window** | `Prefix + p` |

---

## 🤖 Conductor Commands

These commands can be sent from any agent chat or the **User Command Console**.

| Command | Category | Purpose |
|---------|----------|---------|
| `s` or `!status` | Core | Summarize progress and active tracks. |
| `t` or `!test` | Core | Run the full automated test suite. |
| `b` or `!build` | Core | Run the project build system. |
| `!approve <slug>` | Core | Merge a completed task branch into main. |
| `!kb <query>` | Core | Semantic search for architectural guidance. |
| `!kb-refresh` | Core | Re-index the codebase for semantic search. |
| `!quality` | QA | Run manual quality gates (Linting, Security). |
| `!git-sync` | Core | Pull latest changes from remote. |
| `!fleet` | Core | Show real-time health and progress for all agents. |
| `!switch <path>` | Core | Change conductor focus to another project. |

| `!screenshot` | Atari-8bit | Capture current emulator state. |
| `!memory-map` | Atari-8bit | View visual memory allocation. |
| `!profile <file>` | Atari-8bit | Analyze 6502 code cycle counts. |
| `!perf-trend <rt>` | Atari-8bit | View historical performance trend. |

---

## 📁 Configuration Files

| File | Purpose |
|------|---------|
| `config/tmux.iterm2.conf` | iTerm2 tmux configuration |
| `config/tmux.windows-terminal.conf` | Windows Terminal tmux config |
| `config/tmux.default.conf` | Fallback configuration |
| `docs/ITERM2_SETUP.md` | Complete iTerm2 setup guide |
| `docs/WSL_SETUP.md` | Complete WSL setup guide |

**Install config:**
```bash
cp config/tmux.iterm2.conf ~/.tmux.conf  # macOS
cp config/tmux.windows-terminal.conf ~/.tmux.conf  # WSL
tmux kill-server  # Restart tmux
```

---

## 🔧 Common Commands

### Clipboard Integration

**macOS:**
```bash
# Copy from tmux to macOS
tmux save-buffer - | pbcopy

# Paste from macOS to tmux
# Cmd+V in iTerm2
```

**WSL/Windows:**
```bash
# Copy from tmux to Windows
tmux save-buffer - | clip.exe

# Paste from Windows to tmux
# Ctrl+Shift+V in Windows Terminal
```

### Windows Interop (WSL)

```bash
# Open Windows Explorer
explorer.exe .

# Open file in Windows Notepad
notepad.exe file.txt

# Run PowerShell command
powershell.exe "Get-Process"

# Convert WSL path to Windows
wslpath -w /home/user/project

# Convert Windows path to WSL
wslpath '/mnt/c/Users/user'
```

---

## 🐛 Troubleshooting

### Display Issues

```bash
# Reset terminal type
export TERM=xterm-256color
export COLORTERM=truecolor

# Restart tmux
tmux kill-server
tmux
```

### Colors Look Wrong

```bash
# Check terminal detection
./scripts/terminal-detect.sh

# Verify tmux config
cat ~/.tmux.conf | head -20

# Reload tmux config
tmux source-file ~/.tmux.conf
```

### Clipboard Not Working

**macOS:**
```bash
# Test clipboard
echo "test" | pbcopy
pbpaste
```

**WSL:**
```bash
# Test Windows clipboard
echo "test" | clip.exe

# Install wslu if needed
sudo apt install wslu
```

### Pane Borders Look Wrong

```bash
# Ensure using correct config
cp ~/ai_colab/config/tmux.iterm2.conf ~/.tmux.conf

# Restart tmux
tmux kill-server
```

---

## 📊 Terminal Comparison

| Feature | iTerm2 | Windows Terminal |
|---------|--------|------------------|
| **Platform** | macOS | WSL/Windows |
| **True Color** | ✅ | ✅ |
| **Ligatures** | ✅ | ✅ |
| **Clipboard** | pbcopy | clip.exe |
| **Scrollback** | Unlimited | 100,000 lines |
| **Split Panes** | ✅ Native | ✅ Native |
| **Shell Integration** | ✅ Full | ⚠️ Partial |
| **Best For** | macOS users | WSL users |

---

## 🎨 Font Recommendations

Install these fonts for best experience:

**macOS:**
```bash
brew install --cask font-jetbrains-mono-nerd-font
brew install --cask font-fira-code-nerd-font
brew install --cask font-cascadia-code-pl
```

**Windows (for Windows Terminal):**
```powershell
# Download from: https://www.nerdfonts.com/font-downloads
# Or use winget:
winget install JetBrains.Mono.Nerd.Font
winget install Microsoft.Cascadia.Code
```

---

## 📖 Documentation

- **Main README:** `README.md`
- **iTerm2 Guide:** `docs/ITERM2_SETUP.md`
- **WSL Guide:** `docs/WSL_SETUP.md`
- **Implementation:** `docs/TERMINAL_OPTIMIZATION.md`

---

## 🔗 Quick Links

- **iTerm2 Download:** https://iterm2.com/
- **Windows Terminal:** Microsoft Store
- **Nerd Fonts:** https://www.nerdfonts.com/
- **tmux Cheat Sheet:** https://tmuxcheatsheet.com/

---

**Happy collaborating! 🚀**
