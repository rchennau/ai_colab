#!/usr/bin/env bash
# Google Workspace Authentication Helper (Interactive)
# Run this script to manually trigger and complete the login flow.

echo "===================================================="
echo "  Google Workspace Authentication Trigger"
echo "===================================================="
echo ""
echo "This will start an interactive session to trigger login."
echo "1. When prompted, follow the URL to sign in with Google."
echo "2. Paste the authorization code back here if requested."
echo "3. Once you see your profile info, the process is complete."
echo ""

# We run without -y to ensure the CLI stops for interaction/URL display
gemini -p "Use the google-workspace extension to show my profile with people.getMe()"

echo ""
echo "===================================================="
