#!/bin/bash

sudo launchctl unload /Library/LaunchDaemons/com.ljq.SMJobBlessApp.CommandHelper.plist
sudo rm /Library/LaunchDaemons/com.ljq.SMJobBlessApp.CommandHelper.plist
sudo rm /Library/PrivilegedHelperTools/com.ljq.SMJobBlessApp.CommandHelper
