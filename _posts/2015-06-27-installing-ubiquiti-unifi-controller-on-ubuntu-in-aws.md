---
layout: post
title: "Installing Ubiquiti UniFi Controller on Ubuntu in AWS"
description: ""
category: 
tags: [unifi, ubiquiti, ubuntu, aws]
---
{% include JB/setup %}
In this walkthrough we will:

- install the latest release of the Ubiquiti UniFi Controller software on an AWS EC2 instance
- configure nginx as a reverse proxy (to preserve the native port mapping that ships with the controller)
- secure the controller and nginx proxy with our own SSL certificate

<!--more-->
### Instance Bootstrap

I assume that you have some familiarity with AWS - demonstrating security group and instance creation is outside the scope of this walkthough. If you're new to AWS, Amazon has a nice [tutorial](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html) for creating an EC2 instance.

Create a new EC2 security group that opens inbound access to all necessary UniFi ports. I created a group called `unifi-controller` that allows inbound traffic to the following ports.

- TCP 22 (SSH console access)
- TCP 80 (HTTP for nginx proxy server)
- TCP 443 (HTTPS for nginx proxy server)
- TCP 8080 (UniFi device inform port)
- TCP 8081 (UniFi management/shutdown port)
- TCP 8443 (UniFi controller UI/API port)
- TCP 8880 (UniFi guest portal HTTP port)
- TCP 8843 (UniFi guest portal HTTPS port)
- UDP 3478 (STUN for UniFi AP management)

You should restrict the inbound traffic sources to networks where you have deployed UniFi equipment that will talk to the controller.

Create a new EC2 instance. I created a `t2.micro` instance using the official Ubuntu 14.04 AMI, making sure to assign the `unifi-controller` security group to the instance.

Once your new instance has booted, find the host name (e.g. `ec2-x-x-x-x.us-west-2.compute.amazonaws.com`) and connect to it via SSH.

```
me@mycomputer:~$ ssh -i ~/.ssh/my-aws-key.pem ubuntu@YOUR_EC2_HOSTNAME
```

### Package Installation

Add Ubiquiti's Ubuntu repository to your `apt` sources, import their GPG key and then install the UniFi Controller package.

```
echo 'deb http://www.ubnt.com/downloads/unifi/distros/deb/ubuntu ubuntu ubiquiti' | sudo tee /etc/apt/sources.list
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv C0A52C50
sudo apt-get update
sudo apt-get install unifi-beta # 4.x series, or unifi-stable (2.x) or unifi-rapid (3.x)
```

Note that UniFi Switch and UniFi Security Gateway products are only supported by the beta version of the controller (`4.x` series). Also, if you choose the `stable` channel, you'll likely have to modify the target of `JAVA_HOME` in `/etc/init.d/unifi`, as they hardcoded an obsolete path to the JVM. 

You should now be able to connect to the controller UI via your browser at `https://YOUR_EC2_HOSTNAME:8443` and complete the first-run setup wizard for the UniFi controller.

#### DNS Considerations

The rest of this walkthrough only makes sense if you have a 'pretty' DNS name to use for your new controller instance. After all, you probably aren't interested in purchasing an SSL certificate for the domain `ec2-x-x-x-x.us-west-2.compute.amazonaws.com`. This is a good time to set up a DNS `CNAME` for your instance (i.e `unifi.mydomain.com CNAME ec2-x-x-x-x.us-west-2.compute.amazonaws.com`) and purchase an SSL certificate for that domain.

### Changing UniFi SSL Certificate

The UniFi controller package ships with a self-signed SSL certificate by default. This might be OK for a local (LAN) deployment if you're willing to put up with browser warnings, but is definitely a _faux pas_ for a hosted controller.

In good news, it's pretty simple to replace the SSL certificate used by the UniFi application server.

I purchased a SSL certificate for `unifi.mydomain.com`, so I started with the following files:

- unifi.mydomain.com.key (private key in PEM format)
- unifi.mydomain.com.crt (certificate in PEM format)
- ca-chain.crt (intermediate certificate chain in PEM format, NOT including the root CA)

We need to create a certificate package in PKCS12 format, which `openssl` can do for us:

```
openssl pkcs12 -export \
  -in unifi.mydomain.com.crt \
  -inkey unifi.mydomain.com.key \
  -CAfile ca-chain.crt \
  -caname root \
  -out unifi.mydomain.com.p12 \
  -name unifi
```

When prompted to create a password for the new certificate package, use `aircontrolenterprise` as the password.

Now we have a new file `unifi.mydomain.com.p12`, which we can import into the UniFi keystore via `keytool`:

```
keytool -importkeystore \
  -deststorepass aircontrolenterprise \
  -destkeypass aircontrolenterprise \
  -destkeystore /usr/lib/unifi/data/keystore \
  -srckeystore unifi.mydomain.com.p12 \
  -srcstoretype PKCS12 \
  -srcstorepass aircontrolenterprise \
  -alias unifi
```

Finally, restart the UniFi server to pick up the new certificate:

```
sudo service unifi restart
```

Refresh your browser and enjoy your newly-secured UniFi interface.

### Nginx Reverse Proxy

The UniFi Controller ships with the UI on port `8443` by default. I would prefer to see the UI on the default HTTPS port `443` so that my URL can be simplified to `https://unifi.mydomain.com`. However, there are some anecdotal reports on the Ubiquiti forums advising against changing the default UI port - something to do with javascript hardcoding the port value or creating absolute URLs, etc. So I decided to create a reverse proxy with nginx instead.

Install nginx and remove the default site:

```
sudo apt-get install nginx
sudo unlink /etc/nginx/sites-enabled/default
```

Nginx needs your SSL certificate file to contain all intermediate certs as well as your site cert, so combine them together into one file and put it in the nginx config directory. Your private key file should also be available in that directory.

```
cat unifi.mydomain.com.crt ca-chain.crt > /etc/nginx/unifi.mydomain.com.full.crt
```

Here's an example nginx configuration that creates listeners on port `80` and port `443`. I created this as `/etc/nginx/sites-available/unifi`:

```
server_tokens off;
add_header X-Frame-Options SAMEORIGIN;
add_header X-XSS-Protection "1; mode=block";

server {
  listen 80 default_server;
  server_name unifi.mydomain.com;
  return 302 https://unifi.mydomain.com$request_uri;
}

server {
  listen 443;
  server_name unifi.mydomain.com;

  ssl_certificate /etc/nginx/unifi.mydomain.com.full.crt;
  ssl_certificate_key /etc/nginx/unifi.mydomain.com.key;

  ssl on;
  ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC4-SHA';
  ssl_prefer_server_ciphers on;
  ssl_dhparam /etc/nginx/dhparams.pem;

  resolver 8.8.8.8;
    ssl_stapling on;
    ssl_trusted_certificate /etc/nginx/unifi.mydomain.com.full.crt;

  add_header Strict-Transport-Security "max-age=31536000; includeSubdomains";

  location / {
    proxy_pass https://localhost:8443/;
  }
}
```

Create a strong, unique Diffie-Hellman group for the server:

```
sudo openssl dhparam -out /etc/nginx/dhparams.pem 2048
```

Enable the new nginx site:

```
sudo ln -s /etc/nginx/sites-available/unifi /etc/nginx/sites-enabled/
sudo service nginx reload
```

We're done! The UniFi interface should now be available at `https://unifi.mydomain.com` without having to add `:8443` to the URL. Nginx will reverse-proxy all traffic for you. Here's a breakdown of the various behaviors that you'll see based on the source URL:

- `http://unifi.mydomain.com` Nginx will redirect to HTTPS at `https://unifi.mydomain.com`
- `https://unifi.mydomain.com` Nginx will proxy traffic to the UniFi controller, user will not see the port number in their browser. (Preferred use case.)
- `http://unifi.mydomain.com:8443` UniFi controller will redirect to HTTPS at `https://unifi.mydomain.com:8443`
- `https://unifi.mydomain.com:8443` UniFi controller will handle traffic directly, user will see the port number in their browser.

Incidentally, the HTTPS configuration I provided in the example nginx config file is strong enough to earn an `A+` grade on the [Qualys SSL Labs Server Test](https://www.ssllabs.com/ssltest/), so any traffic that is proxied through nginx will enjoy this security.

We've covered installation of the UniFi controller, configuration of nginx as a reverse proxy, and SSL configuration for nginx and the controller itself. That's it for today; hopefully this was useful to you!

