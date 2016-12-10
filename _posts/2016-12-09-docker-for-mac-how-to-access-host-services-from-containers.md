---
layout: post
title: "Docker for Mac: How to access host services from containers"
description: ""
category: 
tags: [docker, macos, containers]
comments: true
---
A few months ago, I built out a docker-compose-based local development environment for our dev team who had been using a long-in-the-tooth vagrant-based environment to run backend databases. We have traditionally run ruby and nodejs services on our macs, and connected to virtualized databases, which now run in containers. 

I expanded the stack by adding adding a web proxy container, to mimic our production traffic routing locally. For the proxy to route requests to upstream services, I needed to find an accessible, consistent network interface on the host. It turns out that this needs a little extra network config on the host.

Now, you could choose to run host services on all network interfaces (`0.0.0.0`), and point containers to the current IP of the host's `en0`, but this requires that you be able to reconfigure your containers every time your mac's IP changes, _and_ it exposes your host service to your local network. You might not want that. Also, if you have no network access, the interface is inaccessible.

The default loopback interface (`lo0`, `127.0.0.1`) isn't available from within Xhyve-based Docker for Mac containers either.

However, there is a recommended solution: you can add a new IP address to the hosts' `lo0` interface, and access services running on host `localhost` via that new IP.

```
sudo ifconfig lo0 alias 169.254.254.254
```

Now your host `localhost` services are accessible from containers via this IP. I took it one step further and added a launchd service to add this interface on every host boot:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>co.cozy.add-lo0-alias-for-docker</string>
  <key>ProgramArguments</key>
  <array>
    <string>/sbin/ifconfig</string>
    <string>lo0</string>
    <string>alias</string>
    <string>169.254.254.254</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
```

A quick shell script checks for the presence of the alias IP. If it's missing, we add it and set up a `launchd` service to persist it:

```bash
#!/usr/bin/env bash

### Docker containers that wish to access services running on the host (this mac)
### need a known IP address for the lo0 interface, 127.0.0.1 will not work.
###
### This adds an alias IP to the lo0 interface of the host.
### It copies a plist script to /Library/LaunchDaemons and enables it via launchctl,
### so that this alias will be added automatically at boot time in future.
### 

ALIAS_IP='169.254.254.254'

LO0_IPS=$( ifconfig | grep -A6 lo0: | grep 'inet '  | cut -d ' ' -f 2 )

if [[ "${LO0_IPS}" =~ "${ALIAS_IP}" ]]; then
  exit 0
else
  echo "We need to add and persist an alias IP to the lo0 network interface."
  echo "Please enter your local sudo password to complete this one-time task:"
  sudo /sbin/ifconfig lo0 alias ${ALIAS_IP}

  if [ ! -e /Library/LaunchDaemons/co.cozy.add-lo0-alias-for-docker.plist ]; then
    DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 
    sudo cp ${DIR}/co.cozy.add-lo0-alias-for-docker.plist /Library/LaunchDaemons/
    sudo chown root:wheel /Library/LaunchDaemons/co.cozy.add-lo0-alias-for-docker.plist
    sudo launchctl load /Library/LaunchDaemons/co.cozy.add-lo0-alias-for-docker.plist
  fi
fi
```

We run that script via our `Makefile` as a precursor task before starting containers, and now we always know that our host is accessible.