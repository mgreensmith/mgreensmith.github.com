---
layout: post
title: "Asynchronous fun with Celluloid and EventSource, part 1"
description: ""
category: 
tags: [ruby, rubygems, sinatra, celluloid, jquery, html5, thin]
comments: true
---
In my Ops Engineer role, I spend a lot of time running scripts from a shell - code deploy workflows, infrastructure converges, etc. These jobs are automated whenever possible but there are always some holdouts that can't be automated, usually for business reasons. Code deploys to tightly-controlled environments, data fixes, anything that the business folk want done "right now" are all tasks that end up being launched manually at a shell. While my team has invested much time and effort into developing robust tooling to perform routine tasks, often we are not the people responsible for deciding *when* these tasks are performed. 

<!--more-->
In his [excellent post about DevOps practices](http://www.somic.org/2010/03/02/the-rise-of-devops/), Dimitry Samovskiy reminds us that DevOps is about developing software for internal needs - I am the user of my own software. When tasks that can only be performed by sysadmins become recurrent and routine, but are requested ad-hoc and at unpredictable times by the customer ('the biz'), it means that I'm stuck doing them, and as a lazy [virtuous programmer](http://threevirtues.com/), this is unacceptable. Accordingly, if we (as Devs/Ops/Sysadmins) can write software that is robust and reliable when we run it ourselves from a shell, then we should be confident in handing off the execution of routine tasks to our internal business folk. 

I propose to Dimitry that the next evolution of DevOps involves writing software that can be used by the project manager, the business analyst, the program manager, any non-technical team member. If I can't automate routine tasks into oblivion, I should be getting someone else to do them! (Preferably the person who would have asked me in the first place.)

It's relatively easy to ask a developer or sysadmin to run an application from a command line and observe the output - we are comfortable in a shell, we know how to set up local development environments and satisfy dependencies, etc. It's much harder to ask this of someone who may never have worked on the command line, so I'm going to focus on providing a web-based tool that can be used to trigger existing backend processes.

In this series of posts, I'm going to take a simple command-line ruby application that performs a long-running job (such as a code deploy) and wrap it in a web interface that can invoke the job asynchronously as well as provide real-time status updates back to the user. It's surprisingly simple to accomplish this, so I'll expand the exercise in stages, using this as an introduction to a few useful ruby gems including Sinatra, Celluloid and Logging.

Let's start with an existing process that looks something like this:

```ruby
# lib/my_backend_process.rb
class MyBackendProcess
  attr_reader :status

  def initialize
    @status = 'idle'
  end

  def run
    change_status('run method invoked')
    sleep 1
    change_status('doing a thing')
    sleep 1
    change_status('doing a second thing')
    sleep 1
    change_status('completed ALL THE THINGS!')
    sleep 1
    change_status('idle')
  end

  private

    def change_status(new_status)
      @status = new_status
      puts @status
    end
end

MyBackendProcess.new.run
```

So this will be our stand-in for a long-running process that completes a task, maybe it's a build process or a code deploy via [capistrano](http://www.capistranorb.com/) or [ansible](http://www.ansibleworks.com/). If I run this from a command line, I get real-time output as the task is running. Our goal will be to create a web UI that can trigger this task and receive the same real-time output from the running process on the server.

Our first step will be to create a web server that can trigger the task. I'll use [Sinatra](http://www.sinatrarb.com/) for this, arguably one of the easiest web frameworks out there. Here's the simplest example of a Sinatra webserver that can trigger the backend process via a POST to the /run URI.

```ruby
# demo_server.rb
require 'sinatra/base'
require 'my_backend_process'

class DemoServer < Sinatra::Base
  set :backend_process, MyBackendProcess.new

  post '/run' do
    settings.backend_process.run
    204 #response without body
  end

end
```
There are a couple of things to note here. First, I'm using a [modular](http://www.sinatrarb.com/intro.html#Sinatra::Base%20-%20Middleware,%20Libraries,%20and%20Modular%20Apps) (subclassing Sinatra::Base) app rather than the 'classic' top-level Sinatra:Application. Secondly, I've created a new instance of `MyBackendProcess` as a *setting*, which is the equivalent of a class variable in Sinatra-speak. There will be a single `MyBackendProcess` to which all connected web clients can share access. 

I'm going to use [thin](http://code.macournoyer.com/thin/) as a container to run my sinatra app, because it supports streaming functionality that we'll be using later. I'll use a `config.ru` to tell [rack](http://rack.github.io/) how to launch my app.

```ruby
# config.ru
# Start the server with:
# bundle exec rackup -s thin

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/lib')

require 'demo_server'
run DemoServer
```

So now we can fire up our webserver and send a POST to /run, expecting to receive a *204* response code.

*server:*

```bash
$ bundle exec rackup -s thin
>> Thin web server (v1.5.1 codename Straight Razor)
>> Maximum connections set to 1024
>> Listening on 0.0.0.0:9292, CTRL+C to stop
run method invoked
doing a thing
doing a second thing
completed ALL THE THINGS!
idle
127.0.0.1 - - [19/Sep/2013 21:41:58] "POST /run HTTP/1.1" 204 - 4.0233
```

*client:*

```bash
$ time http POST localhost:9292/run
HTTP/1.1 204 No Content
Connection: close
Server: thin 1.5.1 codename Straight Razor
X-Content-Type-Options: nosniff

http POST localhost:9292/run  0.25s user 0.04s system 6% cpu 4.300 total
```

OK, we got our 204 response and we see that the process ran, that's a good start. However, we have a couple problems, one being that the process output was displayed only in the webserver log, and secondly that we had to wait for the entire backend process to complete (4 seconds) before getting our response code on the client end. 

Now that we can run ruby via a POST command, let's see if we can run it *asynchronously*. I'm going to use [Celluloid](http://celluloid.io/), which is a concurrency framework that makes multithreaded Ruby programming easier. Incuding celluloid in any Ruby class changes instances of that class into concurrent objects in their own threads, allowing you to call methods and then seamlessly background them with no blocking. See the [Celluloid wiki](https://github.com/celluloid/celluloid/wiki) for better explanations.

To convert `MyBackendProcess` into a celluloid worker, we just make a couple trivial additions:

```ruby
# lib/my_backend_process.rb
require 'celluloid/autostart'    # just require celluloid

class MyBackendProcess
  include Celluloid              # and then include it
  attr_reader :status
<snip>
```

and now we can change our server's invocation of the `run` method and wrap it with celluloid's `async` method.

```ruby
post '/run' do
  settings.backend_process.async.run  # just add .async and now the method won't block
  204 #response without body
end
```

Let's see what this looks like now, from the client and server standpoint.

*server:*

```bash
$ bundle exec rackup -s thin
>> Thin web server (v1.5.1 codename Straight Razor)
>> Maximum connections set to 1024
>> Listening on 0.0.0.0:9292, CTRL+C to stop
127.0.0.1 - - [19/Sep/2013 22:10:26] "POST /run HTTP/1.1" 204 - 0.0080
run method invoked
doing a thing
doing a second thing
completed ALL THE THINGS!
idle
```

*client:*

```bash
$ time http POST localhost:9292/run
HTTP/1.1 204 No Content
Connection: close
Server: thin 1.5.1 codename Straight Razor
X-Content-Type-Options: nosniff

http POST localhost:9292/run  0.25s user 0.04s system 93% cpu 0.310 total
```

That looks much better, we see that the response from the webserver comes before the output of the called backend process. Now we are asynchronous, it wouldn't matter if this process took four seconds, four minutes or four hours as we no longer have to block responses to our web clients to run it.

The big challenge for this part of the exercise will be to push the status output of the backend process ("doing a thing", "doing another thing", etc) to our connected web clients in real time, as it happens.

These days, there are lots of ways to push data in real time from a web server to a connected client. WebSockets, Server-Sent Events, Comet, BOSH, XMPP, and (cheating with) Flash or Java Applets are all viable ways to send push messages, with various levels of server and browser support. Among these tools, Server-Sent Events (SSE) is arguably one of the simplest technologies to implement when building support for server-to-client push updates.

Sinatra has built-in support for SSE when used with a streaming-capable container such as thin (now you know why I chose it!). On the client side, SSE is known as EventSource and is handled with just a few lines of javascript, I'll be using jQuery. So let's make some changes to our Sinatra app.

We will first add a new *setting* to hold an array of connected clients, then we'll add a `get` block to the URI `/stream`. This URI will serve a MIME-type of *text/event-stream*. We store all connected clients in the `:connections` array, and we delete them when they drop their connection.

```ruby
set :connections, []                                  # new setting to hold an array of open connections

get '/stream', :provides => 'text/event-stream' do    # new URI for clients to listen to for SSE events
  stream :keep_open do |out|
    settings.connections << out
    out.callback { settings.connections.delete(out) }
  end
end
```
The SSE protocol is really trivial, it's all HTTP, and messages are in plaintext. They consist of an *event* line with an arbitrary name to distinguish the type of event, and a *data* line containing the contents of the message. Two consecutive newlines signify the end of the data. The format is:

```
event: my_arbitrary_event
data: All my data goes here, it can be split over as many
lines as I please, as long as I don't have two consecutive newline chars.
{ "json": "is fine" }
<xml>also fine</xml>
yaml: totally cool
SSE is completely content-agnostic.
[empty line]
```

For testing purposes, we'll make a POST endpoint that takes a parameter and sends it as a `status_event` to all the connected clients.

```ruby
post '/status_event' do                               # a temporary POST endpoint for testing purposes
  settings.connections.each { |out|                    
    out << "event: status_event\ndata: #{params[:data]}\n\n"    # send the status_event to each client
  }
  204
end
```
We'll need an index page to display these messages. I'm making a very simple page with nothing but a `pre` to hold our output. I'm including jQuery (not really necessary yet) and some JS to connect to the SSE EventSource, parse messages sent as the event type `status_event`, and append their content to the `pre`.

```ruby
get '/' do
  content = <<-EOC.gsub(/^ {6}/, '')  # just a quick helper to unindent our source code.
    <html>
      <head>
        <title>Part 1</title>
      </head>
      <body>
        <pre id='status_messages'></pre>

        <script src="http://code.jquery.com/jquery-1.10.1.min.js"></script>
        <script type="text/javascript">

          var es = new EventSource('/stream');                  // we are now listening to /stream
          es.addEventListener('status_event', function(e) {     // if we get a status_event message
            $('#status_messages').append(e.data + '\\n')        // then add it to the status_messages pre
          }, false);
        </script>
      </body>
    <html>
  EOC
end
```
This seems like a good opportunity to test our progress. Fire up the webserver and load the index page in a browser. The client must connect *before* any messages are sent, as they are only sent to *connected* clients. Now we can POST to the `/status_event` endpoint and see if our parameter appears on our connected web client.

*server*:

```bash
$ bundle exec rackup -s thin
>> Thin web server (v1.5.1 codename Straight Razor)
>> Maximum connections set to 1024
>> Listening on 0.0.0.0:9292, CTRL+C to stop
127.0.0.1 - - [19/Sep/2013 23:19:07] "GET / HTTP/1.1" 200 407 0.0046
127.0.0.1 - - [19/Sep/2013 23:19:10] "POST /status_event?data=hello HTTP/1.1" 204 - 0.0017
```

*and now we test:*

```bash
$ http -f POST localhost:9292/status_event data==hello
HTTP/1.1 204 No Content
Connection: close
Server: thin 1.5.1 codename Straight Razor
X-Content-Type-Options: nosniff
```

And we see that our message immediately shows up on our connected web client.

![screenshot of browser showing hello](/assets/images/2013_09_20_celluloid_eventsource_1.png)

Perfect, we are now able to generate messages in the web server and stream them to clients in real time.

We still have some plumbing work to do on the backend. Namely, we need to get status messages out of a running thread (the instance of our `MyBackgroundProcess` that is performing the `run` method) and into our webserver, so that it may be streamed to clients. Luckily, Celluloid can help us here as well, via [Celluloid::Notifications](https://github.com/celluloid/celluloid/wiki/Notifications), which is a tweaked version of ActiveSupport::Notifications and provides async publish and subscibe functionality for named message streams. That's a lot of words, probably more words than it will take to actually implement this.

I'm going to make a couple of helper classes. The first will be a `StatusSender` which will be included by `MyBackendProcess` and invoked upon every change_status event.

```ruby
# lib/status_sender.rb
require 'celluloid/autostart'

class StatusSender
  include Celluloid
  include Celluloid::Notifications   # this is the important include 

  def initialize(klass)
    @class = klass
  end

  def send_status(message)
    puts "StatusSender publishing message from #{@class.class.name}: #{message}"
    publish("status_event", "#{Time.now} #{@class.class.name}: #{message}")  # celluloid provides 'publish'
  end
end
```

Now that we have celluloid's `publish` action wrapped in the `send_status` method, we can use this in `MyBackendProcess`

```ruby
# lib/my_backend_process.rb
require 'celluloid/autostart'
require 'status_sender'                 # require our new status_sender lib

class MyBackendProcess
  include Celluloid

  attr_reader :status

  def initialize
    @status = 'idle'
    @sender = StatusSender.new(self)    # instantiate a new StatusSender
  end

  def run
    change_status('run method invoked')
    sleep 1
    change_status('doing a thing')
    sleep 1
    change_status('doing a second thing')
    sleep 1
    change_status('completed ALL THE THINGS!')
    sleep 1
    change_status('idle')
  end

  private

    def change_status(new_status)
      @status = new_status
      @sender.send_status(@status)      # instead of writing with a 'puts', send the new status
    end
end
```

Having solved the requirement to publish messages from our running background class, we now need to subscribe to them and pipe them into our webserver. Time for that second helper class, the `StatusObserver`.

```ruby
# lib/status_observer.rb
require 'celluloid/autostart'

class StatusObserver
  include Celluloid
  include Celluloid::Notifications            # again, the important include

  def initialize(server)
    @server = server
    subscribe "status_event", :status_event   # celluloid provides the subscribe method  
  end

  def status_event(*args)
    puts "StatusObserver received status_event message: #{args[1]}"
    @server.settings.connections.each { |out| out << "event: #{args[0].to_s}\ndata: #{args[1]}\n\n" }
  end
end
```

This `StatusObserver` will become a component of the webserver. It will subscribe to events on the *status_event* channel and invoke the `status_event` method when a message is received. You'll recognize the core action of the `status_event` method - it's identical to the action of the temporary POST event we created earlier - streaming the message to all connected clients.

Now we will add this library to our server. We create a new instance of the `StatusObserver` as a setting (class variable) called `:observer`, but we will never need to access it in normal use. The `StatusObserver` needs access to the server's settings (namely the `:connections` array), so we pass in a reference to `self` when we create it.

```ruby
require 'sinatra/base'
require 'status_observer'                     # require our new status_observer
require 'my_backend_process'

class DemoServer < Sinatra::Base

  set :observer, StatusObserver.new(self)     #instantiate a new StatusObserver
  set :backend_process, MyBackendProcess.new
  set :connections, []
<snip>
```

OK, that should be it for plumbing between `MyBackendProcess` and the server. The very last thing that we have to accomplish is the ability to trigger the backend process from a connected web client. We already have a POST endpoint called `/run`, it shouldn't be too much work to add a button that will POST to this URI and fire off the backend task.

A couple quick additions to our index page later, and we end up with something like this.

```ruby
get '/' do
  content = <<-EOC.gsub(/^ {6}/, '')
    <html>
      <head>
        <title>Part 1: Status to Web</title>
      </head>
      <body>
        <input type="button" id="btn_run" value="Run Backend Process"> 
        <pre id='status_messages'></pre>

        <script src="http://code.jquery.com/jquery-1.10.1.min.js"></script>
        <script type="text/javascript">
          $('#btn_run').click(function () {
            $.post('/run');
          });

          var es = new EventSource('/stream');
          es.addEventListener('status_event', function(e) {
            $('#status_messages').append(e.data + '\\n')
          }, false);
        </script>
      </body>
    <html>
  EOC
end
```

We now have a button that triggers an AJAXy POST to the `/run` URI, and nothing else. We don't bother to capture the output of the POST, as we already know it's a 204 with no content. The real output will come from the SSE events.

The end result of all our work is a web UI that contains a button to trigger an asynchronous backend process:

![screenshot of browser showing run button](/assets/images/2013_09_20_celluloid_eventsource_2.png)

When we push the button, we see a POST to `/run` appear in our log, and then our `StatusSender` and `StatusObserver` exchanging messages generated by `MyBackendProcess`.

```bash
$ bundle exec rackup -s thin
>> Thin web server (v1.5.1 codename Straight Razor)
>> Maximum connections set to 1024
>> Listening on 0.0.0.0:9292, CTRL+C to stop
127.0.0.1 - - [20/Sep/2013 00:01:11] "GET / HTTP/1.1" 200 564 0.0033
127.0.0.1 - - [20/Sep/2013 00:03:19] "POST /run HTTP/1.1" 204 - 0.0023
StatusSender publishing message from MyBackendProcess: run method invoked
StatusObserver received status_event message: 2013-09-20 00:03:19 -0700 MyBackendProcess: run method invoked
StatusSender publishing message from MyBackendProcess: doing a thing
StatusObserver received status_event message: 2013-09-20 00:03:20 -0700 MyBackendProcess: doing a thing
StatusSender publishing message from MyBackendProcess: doing a second thing
StatusObserver received status_event message: 2013-09-20 00:03:21 -0700 MyBackendProcess: doing a second thing
StatusSender publishing message from MyBackendProcess: completed ALL THE THINGS!
StatusObserver received status_event message: 2013-09-20 00:03:22 -0700 MyBackendProcess: completed ALL THE THINGS!
StatusSender publishing message from MyBackendProcess: idle
StatusObserver received status_event message: 2013-09-20 00:03:23 -0700 MyBackendProcess: idle
```

As promised, we see real-time messages appearing in the web client, one each second as the backend process performs its task.

![screenshot of browser showing completed workflow](/assets/images/2013_09_20_celluloid_eventsource_3.png)

We've achieved our objective for part one of this series. in future posts I'll be fleshing out this tool to provide a real logging framework, server side state information, and other enhancements.

All the code from this post is available at [my GitHub account](https://github.com/mgreensmith/async_tasks_from_webui_example).