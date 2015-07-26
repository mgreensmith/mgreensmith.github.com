---
layout: post
title: "Knife::Hosts, a plugin to generate host file records"
description: "A knife plugin that cleans up node names into their easy-to-remember components and prints names and IPs formatted for inclusion in a hosts file."
category: 
tags: [chef, knife, rubygems]
comments: true
---

### Problem
We have a bunch of chef-managed servers that are physical machines hosted at Rackspace. Rackspace's host naming scheme involves a 6-digit number preceeding the hostname, ie `123456-app1.foo.com`. These names are hard to remember, and we don't have public DNS records for all of our chef-controlled servers. We would prefer not to make public DNS records, but we also don't want to have to `knife ssh "name:123456-app1.foo.com"` (after doing a `knife show` to find the actual node name).

### Solution

I wrote a knife plugin that cleans up node names into their easy-to-remember components and prints names and IPs formatted for inclusion in a hosts file.

<!--more-->
I added a couple of extra options to simplify hostnames automatically.

Since all (most) of the servers that I connect to are at the same domain `foo.com`, I drop the last two elements and add the remainder as an alias. So the output for a host named `app1.foo.com` with IP `10.0.0.1` would look like:

```
10.0.0.1 app1.foo.com app1
```

which I put into my hosts file, and now I can just `ssh app1` to get to that server.

Also, I added an otion to remove the leading Rackspace identifying number. So the output for a host named `123456-app1.foo.com` with IP `10.0.0.1` would look like:

```
10.0.0.1 123456-app1.foo.com app1.foo.com app1
```

And of course, because this is a knife plugin, you can generate output for all your chef-controlled hosts at once, or limit the output using a chef search query.

### Getting It

The gem is available at [rubygems.org](https://rubygems.org/gems/knife-hosts) as well as from [GitHub](https://github.com/mgreensmith/knife-hosts).

### Installation

Add this line to your application's Gemfile:

    gem 'knife-hosts'

And then execute:

    $ bundle

Or install it yourself with:

    $ gem install knife-hosts

### Usage

```
knife hosts [-di] [QUERY]
```

Copy the output to your `/etc/hosts`
Use an optional chef search query to limit the output.

We add friendly aliases a couple of ways:

1. We strip trailing domain elements (default 2) from the end of node names and add an alias:

```
10.1.1.1 foo.bar.com foo
```
You can override the number of domain elements stripped with the `-d [N]`, `--drop-elements [N]` option, and disable it completely with `-d 0`

2. Rackspace prefaces the hostname of physical nodes with an identifying number, eg `000000-foo.bar.com`
We strip this number and add the leftover host name as an alias, eg:

```
10.1.1.1 000000-foo.bar.com foo.bar.com
```
If you happen to name your nodes with a leading number and then a hyphen, you may want to disable this behavior with `-i`, `--ignore-strip-rackspace` option.
