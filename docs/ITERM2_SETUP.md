# iTerm2 Setup Guide for ai-colab

This guide provides complete setup instructions for running ai-colab on macOS with iTerm2 for optimal multi-agent development experience.

## 🎯 Why iTerm2 for ai-colab?

iTerm2 is the **recommended terminal** for ai-colab on macOS because:

- ✅ **Superior split-pane management** - Monitor multiple agents simultaneously
- ✅ **Excellent scrollback history** - Review long agent conversations
- ✅ **Shell integration** - Enhanced status indicators and prompts
- ✅ **True color support** - Perfect rendering of tmux themes
- ✅ **Unicode & ligatures** - Beautiful code and symbol rendering
- ✅ **Instant replay** - Review previous terminal states
- ✅ **Triggers & autocmds** - Automate workflows
- ✅ **Searchable history** - Find previous agent outputs quickly

---

## 📋 Installation & Setup

### 1. Install iTerm2

**Option A: Direct Download (Recommended)**
```bash
# Download from: https://iterm2.com/downloads/stable/latest
# Or use curl:
curl -L https://iterm2.com/downloads/stable/iTerm2_3_5_10.zip -o iterm2.zip
unzip iterm2.zip
mv iTerm.app /Applications/
```

**Option B: Homebrew**
```bash
brew install --cask iterm2
```

### 2. Install Required Fonts

For best experience with powerline symbols and ligatures:

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Nerd Fonts (choose one)
brew install --cask font-jetbrains-mono-nerd-font
brew install --cask font-fira-code-nerd-font
brew install --cask font-cascadia-code-pl
```

### 3. Configure iTerm2 Preferences

Open iTerm2 → Preferences (Cmd+,):

#### **Profiles → Text**
```
Font: JetBrains Mono Nerd Font
Size: 13-15 (depending on display)
Enable ligatures: ✓
Use built-in powerline: ✓
```

#### **Profiles → Colors**
```
Color Presets: Import "ai-colab Dark" (see below)
Minimum contrast: Adjust for readability
```

#### **Profiles → Window**
```
Transparency: 5-10% (optional)
Blur: ✓ (optional, for aesthetics)
```

#### **Profiles → Terminal**
```
Terminal type: xterm-256color
Report terminal type: ✓
Allow terminal to set window title: ✗ (prevents conflicts)
```

#### **General → Selection**
```
Copy to clipboard on selection: ✗ (disable to avoid accidental copies)
Triple click selects line: ✓
```

#### **Keys → Hotkey**
```
Show/hide all windows with hotkey: ⌥` (Option-Backtick)
```

### 4. Install Shell Integration

iTerm2's shell integration provides enhanced features:

```bash
# In iTerm2, run:
curl -L https://iterm2.com/shell_integration/bash -o ~/.iterm2_shell_integration.bash

# Add to ~/.bashrc or ~/.zshrc:
echo '[ -f ~/.iterm2_shell_integration.bash ] && source ~/.iterm2_shell_integration.bash' >> ~/.zshrc
```

**Features enabled:**
- ✓ Status bar with job status
- ✓ Download handling
- ✓ Upload integration
- ✓ Smart cursor placement
- ✓ Command markers in scrollback

---

## 🎨 ai-colab Color Scheme

Import this color scheme into iTerm2:

**Preferences → Profiles → Colors → Color Presets → Import**

Save as `ai-colab-dark.itermcolors`:

```json
{
  "Ansi 0 Color": { "Red": 58, "Green": 58, "Blue": 58 },
  "Ansi 1 Color": { "Red": 224, "Green": 108, "Blue": 117 },
  "Ansi 2 Color": { "Red": 152, "Green": 195, "Blue": 121 },
  "Ansi 3 Color": { "Red": 229, "Green": 192, "Blue": 123 },
  "Ansi 4 Color": { "Red": 97, "Green": 175, "Blue": 239 },
  "Ansi 5 Color": { "Red": 198, "Green": 120, "Blue": 221 },
  "Ansi 6 Color": { "Red": 86, "Green": 182, "Blue": 194 },
  "Ansi 7 Color": { "Red": 171, "Green": 178, "Blue": 191 },
  "Ansi 8 Color": { "Red": 92, "Green": 99, "Blue": 112 },
  "Ansi 9 Color": { "Red": 224, "Green": 108, "Blue": 117 },
  "Ansi 10 Color": { "Red": 152, "Green": 195, "Blue": 121 },
  "Ansi 11 Color": { "Red": 229, "Green": 192, "Blue": 123 },
  "Ansi 12 Color": { "Red": 97, "Green": 175, "Blue": 239 },
  "Ansi 13 Color": { "Red": 198, "Green": 120, "Blue": 221 },
  "Ansi 14 Color": { "Red": 86, "Green": 182, "Blue": 194 },
  "Ansi 15 Color": { "Red": 255, "Green": 255, "Blue": 255 },
  "Background Color": { "Red": 30, "Green": 30, "Blue": 30 },
  "Foreground Color": { "Red": 212, "Green": 212, "Blue": 212 },
  "Cursor Color": { "Red": 129, "Green": 161, "Blue": 193 },
  "Cursor Text Color": { "Red": 30, "Green": 30, "Blue": 30 },
  "Selection Background Color": { "Red": 62, "Green": 68, "Blue": 81 }
}
```

Or create manually with these values (RGB 0-255).

---

## 🔧 tmux Configuration for iTerm2

### Install the ai-colab tmux config

During `./install.sh`, accept the prompt to install the iTerm2 tmux configuration.

Or manually:
```bash
cp config/tmux.iterm2.conf ~/.tmux.conf
```

### Key Features

The iTerm2-optimized tmux config includes:

**Enhanced Pane Management:**
- Vim-style navigation (Ctrl-a + h/j/k/l)
- Resizable panes (Ctrl-a + H/J/K/L)
- Persistent pane labels for agents
- Beautiful border styling

**Clipboard Integration:**
- Copy to macOS clipboard: `Ctrl-a + y`
- Automatic pbcopy integration

**Performance Optimizations:**
- 100,000 line scrollback (iTerm2 handles this well)
- Focus events enabled
- True color support
- Optimized redraw rates

---

## 🚀 Using ai-colab in iTerm2

### Launch the Dashboard

```bash
cd ~/ai_colab
./launch.sh
```

### iTerm2-Specific Features

**1. Split Pane Monitoring**

iTerm2's native splits + tmux splits = ultimate flexibility:

```bash
# Split iTerm2 vertically (Cmd+D)
# Run dashboard in left pane
./launch.sh

# Run individual agent in right pane
gemini

# Monitor both simultaneously
```

**2. Scrollback Search**

- **Cmd+F** - Search current pane
- **Cmd+Shift+H** - Search history
- **Instant Replay** - Review previous states

**3. Session Management**

```bash
# Save current window arrangement
# Bookmarks → Save Window Arrangement

# Restore later
# Bookmarks → Load Window Arrangement
```

**4. Triggers for Automation**

Set up triggers for agent events:

**Preferences → Profiles → Advanced → Triggers**

Example trigger:
```
Regular expression: "ERROR|FAIL|Critical"
Action: Growl/Notification
Parameters: Agent Alert
```

---

## ⚡ Performance Tips

### 1. Optimize Scrollback

For long agent sessions:

**Preferences → Profiles → Terminal:**
```
Save scrollback buffer: ✓
Unlimited scrollback: ✓ (or set to 100000)
```

### 2. Reduce Visual Effects

If experiencing lag:

**Preferences → Advanced:**
```
Disable GPU acceleration: ✗ (keep enabled)
Reduce motion: ✓ (if needed)
```

### 3. Font Rendering

For crisp text:

**Preferences → Profiles → Text:**
```
Anti-aliasing: ✓
Sub-pixel font rendering: ✓
Use thin strokes for bold text: ✓
```

### 4. Memory Management

iTerm2 can use significant RAM with many panes:

**Preferences → Advanced:**
```
Memory warning threshold: 2GB
```

---

## 🎯 Workflow Optimizations

### 1. Hotkey Window

Configure iTerm2 as a drop-down terminal:

**Preferences → Keys → Hotkey:**
```
Show/hide all windows: ⌥` (Option-Backtick)
```

Quick access during coding sessions!

### 2. Smart Window Titles

ai-colab sets informative window titles. Enhance with:

**Preferences → Profiles → Terminal → Emulation:**
```
Terminal may set window title: ✗ (disable to keep consistent)
```

### 3. Badge for Status

Show agent status as a badge:

**Preferences → Profiles → Terminal → Badge:**
```
Badge text: #{?client_prefix,⌨️,}#{pane_title}
```

### 4. Growl/Notification Integration

Get notified of agent events:

```bash
# In agent wrappers, add:
echo -e "\a"  # Terminal bell triggers notification
```

---

## 🔍 Troubleshooting

### Issue: Colors look wrong in tmux

**Solution:**
```bash
# Ensure TERM is set correctly
export TERM=xterm-256color
export COLORTERM=truecolor

# Restart tmux
tmux kill-server
tmux
```

### Issue: Font not rendering correctly

**Solution:**
- Install Nerd Fonts
- Restart iTerm2
- Check: Preferences → Profiles → Text → Font

### Issue: Scrollback not working in tmux

**Solution:**
```bash
# Add to ~/.tmux.conf:
set -g mouse on

# Reload tmux config
tmux source-file ~/.tmux.conf
```

### Issue: Shell integration not working

**Solution:**
```bash
# Reinstall shell integration
curl -L https://iterm2.com/shell_integration/zsh -o ~/.iterm2_shell_integration.zsh

# Add to ~/.zshrc:
source ~/.iterm2_shell_integration.zsh

# Restart iTerm2
```

### Issue: Pane borders look wrong

**Solution:**
```bash
# Ensure using the iTerm2 config
cp ~/ai_colab/config/tmux.iterm2.conf ~/.tmux.conf

# Restart tmux
tmux kill-server
```

---

## 📊 iTerm2 vs Alternatives

| Feature | iTerm2 | Terminal.app | Warp |
|---------|--------|--------------|------|
| **Split Panes** | ✓ Native | ✗ | ✓ |
| **Search** | ✓ Advanced | Basic | ✓ AI-powered |
| **Shell Integration** | ✓ Full | ✗ | ✓ |
| **True Color** | ✓ | ✓ | ✓ |
| **Ligatures** | ✓ | ✗ | ✓ |
| **Scrollback** | ✓ Unlimited | Limited | ✓ |
| **Customization** | ✓ Extensive | Basic | Moderate |
| **Privacy** | ✓ Local | ✓ Local | ⚠ Cloud features |
| **Best For** | Power users | Basic use | AI-assisted |

---

## 🔗 Useful iTerm2 Features for ai-colab

### 1. Paste History
**Cmd+Shift+H** - See all pasted text

### 2. Instant Replay
**Cmd+Option+B** - Replay terminal session

### 3. Broadcast Input
**Cmd+Option+I** - Type to all panes simultaneously

### 4. Capture Previews
**Cmd+Option+I** - Screenshot of pane

### 5. Autocomplete
**Cmd+;** - Suggest text from scrollback

---

## 📝 Quick Reference

```bash
# Check terminal detection
./scripts/terminal-detect.sh

# Install with iTerm2 optimizations
./install.sh

# Launch dashboard
./launch.sh

# Copy to macOS clipboard
tmux save-buffer - | pbcopy

# iTerm2 shell integration
source ~/.iterm2_shell_integration.zsh

# Reload tmux config
tmux source-file ~/.tmux.conf
```

---

## 🎓 Advanced: iTerm2 API

iTerm2 has a Python API for automation:

```python
#!/usr/bin/env python3
import iterm2

async def main(connection):
    app = await iterm2.AsyncApp(connection)
    window = app.current_window
    tab = window.current_tab
    pane = tab.current_pane
    
    # Send command to pane
    await pane.async_send_text("cd ~/ai_colab && ./launch.sh\n")

iterm2.run_until_complete(main)
```

Use this to automate ai-colab workflows!

---

**Happy collaborating with iTerm2! 🍎✨**
