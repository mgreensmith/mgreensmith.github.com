---
layout: post
title: "Protecting chef attributes from overwrites with a loopback mechanism"
description: ""
category: 
tags: [chef, rubygems, ridley]
---
{% include JB/setup %}

"Workflow is hard" is a perennial complaint among the Opscode Chef users that I know. If you have multiple committers, multiple tools to update the chef server, and multiple branches in your cookbooks git repository, it's easy for things to get out of sync. Sometimes we see workflow mistakes where a running configuration may have been updated in the chef server but not committed to git. There's no simple mechanism to pull your running config (environments, roles, etc) out of your chef server and into your source repository, and it's frustrating when your 'source of truth' (git) is no longer so.

<!--more-->
We recently developed a deployment tool that is reponsible for updating certain chef environment attributes (version tags) via the chef API. By performing direct API calls to the chef server to update an environment, we end up with a problem: these changes are not reflected in the environment files in our git repo. If someone were to manually upload that environment using `knife environment from file`, the changes made with the deployment tool via the chef API would be overwritten and lost.

The solution to this problem was to create a 'loopback mechanism' whereby the attributes that were controlled by the deployer tool could only be updated by that tool, and could not be modified by uploading the environment file via knife. We use an API client to query the current value of that attribute from the chef server, and dynamically insert that value into the local environment file when uploading via knife.

Here's the entire lib, we're using the (awesome) [Ridley](https://github.com/RiotGames/ridley) chef API client.

```ruby
# lib/loopback_attrs.rb

require "ridley"

class Hash
  def self.keys_to_s(value)
    return value if not value.is_a?(Hash)
    hash = value.inject({}){|memo,(k,v)| memo[k.to_s] = Hash.keys_to_s(v); memo}
    return hash
  end
end

class LoopbackAttrs
  def self.fetch(environment, attr_dotted_path)
    chef = get_chef_client
    env = chef.environment.find(environment)
    # Note that we are fetching only 'override' attributes
    attributes = Hash.keys_to_s(env.override_attributes.to_hash)
    # chef requires Hashie, so we get the "dig a dotted path" helper.
    return attributes.dig(attr_dotted_path)
  end

  private 
  def self.get_chef_client
    return Ridley.new(
      server_url:  <url_for_chef_server>,
      client_name: <chef_node_name>,
      client_key:  <chef_client_key>
    )
  end
end

```

And now we use the loopback mechanism in our chef environment file.

```ruby
# environments/production.rb
name "production"
description "My production environment"

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "..", "lib")))
require 'loopback_attrs'

# We only want to set this version with our deployer tool.
# The LoopbackAttr mechanism sets the attribute to whatever is currently in opscode.
my_application_version = LoopbackAttrs.fetch("production", "my_application.version")

override_attributes(
  :my_application => {
    :version => my_application_version
  }
)
```

From now on, any time someone uploads the production environment with `knife environment from file`, the current value for `:my_application => :version` will be pulled directly from the chef server and inserted into the environment attributes before uploading. It's an easy way to make an attribute functionally immutable via knife. Hopefully this mechanism can help improve someone else's chef workflow too.