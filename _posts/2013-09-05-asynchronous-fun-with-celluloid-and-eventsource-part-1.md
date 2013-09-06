---
layout: post
title: "Asynchronous fun with Celluloid and EventSource, part 1"
description: ""
category: 
tags: [ruby, rubygems, sinatra, celluloid, jquery, html5]
---
{% include JB/setup %}
In my Ops Engineer role, I spend a lot of time running scripts from a shell - code deploy workflows, infrastructure converges, etc. These jobs are automated whenever possible but there are always some holdouts that can't be automated, usually for business reasons. Code deploys to tightly-controlled environments, data fixes, anything that the business folk want done "right now" are all tasks that end up being launched manually at a shell. While my team has invested much time and effort into developing robust tooling to perform routine tasks, often we are not the people responsible for deciding *when* these tasks are performed. 

<!--more-->
In his [excellent post about DevOps practices](http://www.somic.org/2010/03/02/the-rise-of-devops/), Dimitry Samovskiy reminds us that DevOps is about developing software for internal needs - I am the user of my own software. When tasks that can only be performed by sysadmins become recurrent and routine, but are requested ad-hoc and at unpredictable times by the customer ('the biz'), it means that I'm stuck doing them, and as a lazy [virtuous programmer](http://threevirtues.com/), this is unacceptable. Accordingly, if we (as Devs/Ops/Sysadmins) can write software that is robust and reliable when we run it ourselves from a shell, then we should be confident in handing off the execution of routine tasks to our internal business folk. 

I propose to Dimitry that the next evolution of DevOps involves writing software that can be used by the project manager, the business analyst, the program manager, any non-technical team member. If I can't automate routine tasks into oblivion, I should be getting someone else to do them! (Preferably the person who would have asked me in the first place.)

It's relatively easy to ask a developer or sysadmin to run an application from a command line and observe the output - we are comfortable in a shell, we know how to set up local development environments and satisfy dependencies, etc. It's much harder to ask this of someone who may never have worked on the command line, so I'm going to focus on provising a web-based tool that can be used to trigger existing backend processes.

In this series of posts, I'm going to take a simple command-line ruby application that performs a long-running job, and wrap it in a web interface that can invoke the job asynchronously as well as provide real-time status updates back to the user. It's surprisingly simple to accomplish this, so I'll expand 


These days, there are lots of ways to push data in real time from a web server to a connected client. WebSockets, Server-Sent Events, Comet, BOSH, XMPP, and (cheating with) Flash or Java Applets are all viable ways to send push messages, with various levels of server and browser support. Among these tools, Server-Sent Events (SSE) is arguably one of the simplest technologies to implement when building support for server-to-client push updates.

When 

