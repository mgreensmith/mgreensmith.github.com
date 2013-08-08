---
layout: post
title: "Knife::Hosts, a plugin to generate host file records"
description: ""
category: 
tags: [chef, knife, rubygems]
---
{% include JB/setup %}

##Problem
We don't have public DNS records for all of our chef-controlled servers.

##Solution

Make a knife plugin to print node names and IPs formatted for inclusion in a hosts file.

## Installation

Add this line to your application's Gemfile:

    gem 'knife-hosts'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install knife-hosts

## Usage

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
