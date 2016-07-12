---
layout: open-source
title: Open Source
tags: []
comments: false
share: false
image:
  feature: bg-header-index-short.jpg
---

Whenever possible, I release my work to the community. Here are a few small things that I've written over the years.

### Ruby Gems

{% include _project-description.html name='Pry-Auditlog' url='https://github.com/mgreensmith/pry-auditlog' github='https://github.com/mgreensmith/pry-auditlog' rubygems='https://rubygems.org/gems/pry-auditlog' description='A plugin for the Pry REPL that enables logging of any combination of Pry input and output to a configured audit file.' %}

{% include _project-description.html name='Berksfiler' url='https://github.com/mgreensmith/berksfiler' github='https://github.com/mgreensmith/berksfiler' rubygems='https://rubygems.org/gems/berksfiler' description='Programatically generate Berksfiles for Chef cookbooks.' %}

{% include _project-description.html name='Knife::Hosts' url='https://github.com/mgreensmith/knife-hosts' github='https://github.com/mgreensmith/knife-hosts' rubygems='https://rubygems.org/gems/knife-hosts' description='Knife (Chef CLI) plugin to print node names and IPs formatted for inclusion in a hosts file.' %}

{% include _project-description.html name='Raven::Processor::SanitizeSSN' url='https://github.com/cozyco/raven-processor-sanitizessn' github='https://github.com/cozyco/raven-processor-sanitizessn' rubygems='https://rubygems.org/gems/raven-processor-sanitizessn' description='(deprecated) A processor plugin for the Sentry Raven gem that sanitizes Social Security Number fields.' %}

### GoCD Tools

I created some tools to help ease a company transition from [Jenkins CI](https://jenkins-ci.org/) to the [GoCD](http://www.go.cd) continuous delivery platform.

{% include _project-description.html name='GoCD Dashboard' url='https://github.com/mgreensmith/gocd-dashboard' github='https://github.com/mgreensmith/gocd-dashboard' description='An alternative dashboard for GoCD that mimics the Jenkins dashboard view. It is functionally equivalent to the GoCD dashboard and provides (in my opinion) a much better user experience.' %}

{% include _project-description.html name='GoCD Wallboard' url='https://github.com/mgreensmith/gocd-wallboard' github='https://github.com/mgreensmith/gocd-wallboard' description='A visualizer for GoCD pipeline status, suitable for display on a wall monitor. It can display the status of all available pipelines or pipelines from a single pipeline group.' %}

### Sensu Plugins

I've written a number of plugins for the [Sensu](https://sensuapp.org/) monitoring framework. Here are a few that I've been able to release publically.

{% include _project-description.html name='metrics-process-status' url='https://github.com/sensu-plugins/sensu-plugins-process-checks/blob/master/bin/metrics-process-status.rb' github='https://github.com/sensu-plugins/sensu-plugins-process-checks/blob/master/bin/metrics-process-status.rb' description='For all processes owned by a user AND/OR matching a provided process name substring, return selected memory metrics from /proc/[PID]/status' %}

{% include _project-description.html name='check-jenkins-build-time' url='https://github.com/sensu-plugins/sensu-plugins-jenkins/blob/master/bin/check-jenkins-build-time.rb' github='https://github.com/sensu-plugins/sensu-plugins-jenkins/blob/master/bin/check-jenkins-build-time.rb' description='Alert if the last successful build timestamp of a Jenkins job is older than a specified time duration OR not within a specific daily time window.' %}

{% include _project-description.html name='check-bluepill-procs' url='https://github.com/sensu-plugins/sensu-plugins-bluepill/blob/master/bin/check-bluepill-procs.rb' github='https://github.com/sensu-plugins/sensu-plugins-bluepill/blob/master/bin/check-bluepill-procs.rb' description='Monitor the status of applications and processes running under the bluepill process supervisor. Alerts if any process is down or if a manually specified application has no processes loaded' %}

{% include _project-description.html name='check-jsonwhois-domain-expiration' url='https://github.com/sensu-plugins/sensu-plugins-network-checks/blob/master/bin/check-jsonwhois-domain-expiration.rb' github='https://github.com/sensu-plugins/sensu-plugins-network-checks/blob/master/bin/check-jsonwhois-domain-expiration.rb' description='Check domain expiration dates using the https://jsonwhois.com API' %}

### Personal Projects

{% include _project-description.html name='CVE Name Generator' url='http://cve.name' github='https://github.com/mgreensmith/cvename' description='Discovered a critical vulnerability in a widely used software package? Need a scary-sounding name (heartbleed, shellshock, etc.) to help drive fear into the hearts of internet users everywhere? You need the <a href="http://cve.name">CVE Name Generator!</a>' %}
