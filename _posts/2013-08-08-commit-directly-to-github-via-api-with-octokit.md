---
layout: post
title: "Commit directly to GitHub via API with Octokit"
description: ""
category: 
tags: [github, octokit, rubygems]
---
{% include JB/setup %}

GitHub's full-featured API allows us to do really neat things, like commit to a git repository programmatically, without having to have a local git installation or a local copy of the repo.

Huge thanks to [Matt Swanson](http://mdswanson.com/blog/2011/07/23/digging-around-the-github-api-take-2.html) for doing the digging and figuring out the (relatively) easy 5-step process for making a commit. I want to take his work one step further and do the whole commit in code. [Ocktokit](http://octokit.github.io/) is the official wrapper library for the GitHub API, and there's a ruby flavor available as a gem, so let's make a programmatic commit to GitHub with octokit!

<!--more-->
*(Skip to the end for the [full code listing](#full_listing))*

Set up a github client instance; you can authenticate with a username and password, or an [OAuth token](http://www.lornajane.net/posts/2012/github-api-access-tokens-via-curl)

*Update: I wrote this post against Octokit 1.x, but Octokit 2.0 is now stable, and `:oauth_token` has been renamed to `:access_token`*

```ruby
require 'octokit'

github = Octokit::Client.new( :access_token => "1hw9782egfbioj3fo32hf893fgb32yfv238fy" ) # Octokit 2.x
#github = Octokit::Client.new( :oauth_token => "1hw9782egfbioj3fo32hf893fgb32yfv238fy" ) # Octokit 1.x
# or
#github = Octokit::Client.new( :login => "me", :password => "sekret" )

# set up some vars:
repo = 'mgreensmith/api-test'
ref = 'heads/master'
```

I'll be using the `master` branch, which is referenced as `heads/master` in git-speak. Responses from Octokit are returned as a [Hashie::Mash](https://github.com/intridea/hashie), so we can use dotted-path notation to drill into the nested hash and get the correct attribute. We first find and store the SHA for the latest commit (the commit that `heads/master` points at, aka the `HEAD` of `master` branch). 

```ruby
sha_latest_commit = github.ref(repo, ref).object.sha
```

Find and store the SHA for the tree object that the `heads/master` commit points to.

```ruby
sha_base_tree = github.commit(repo, sha_latest_commit).commit.tree.sha
```

Now we know the tree upon which we will base our new commit.

Let's put some data into the commit. Start by creating a new `blob` object by base64-encoding a local object (`my_content`) and then pushing it to get a blob SHA in return. We then push a new tree object containing that blob at a particular file path and capture the SHA of this new tree. We are basing this tree upon the existing remote `sha_base_tree` object that we obtained in the last step (the tree which represents the object at which the HEAD commit of `master` is pointed).

```ruby
file_name = File.join("some_dir", "new_file.txt")
blob_sha = github.create_blob(repo, Base64.encode64(my_content), "base64")
sha_new_tree = github.create_tree(repo, 
                                   [ { :path => file_name, 
                                       :mode => "100644", 
                                       :type => "blob", 
                                       :sha => blob_sha } ], 
                                   {:base_tree => sha_base_tree }).sha
```

Now we will generate a new commit containing the tree object that we just created. We are making a regular commit, and we will specify `HEAD` of `master` as the parent commit. If this were a merge commit, we would need to specify two parent commits. From the response, we capture the SHA of this new commit.

```ruby
commit_message = "Committed via Octokit!"
sha_new_commit = github.create_commit(repo, commit_message, sha_new_tree, sha_latest_commit).sha
```

Finally, we move the reference `heads/master` to point to our new commit object.

```ruby
updated_ref = github.update_ref(repo, ref, sha_new_commit)
puts updated_ref
```

Octokit will throw exceptions on any API failure, so if we've made it this far, congratulations, we're done! Check out your fresh new commit in GitHub.

For further learning, check out the [GitHub API documentation](http://developer.github.com/v3/) and the [Octokit RubyDocs](http://rdoc.info/gems/octokit).

<a id="full_listing"></a>
Here's the full code listing:

```ruby
require 'octokit'

github = Octokit::Client.new( :access_token => "1hw9782egfbioj3fo32hf893fgb32yfv238fy" ) # Octokit 2.x
#github = Octokit::Client.new( :oauth_token => "1hw9782egfbioj3fo32hf893fgb32yfv238fy" ) # Octokit 1.x
# or
#github = Octokit::Client.new(:login => "me", :password => "sekret")

# set up some vars:
repo = 'mgreensmith/api-test'
ref = 'heads/master'

sha_latest_commit = github.ref(repo, ref).object.sha
sha_base_tree = github.commit(repo, sha_latest_commit).commit.tree.sha
file_name = File.join("some_dir", "new_file.txt")
blob_sha = github.create_blob(repo, Base64.encode64(my_content), "base64")
sha_new_tree = github.create_tree(repo, 
                                   [ { :path => file_name, 
                                       :mode => "100644", 
                                       :type => "blob", 
                                       :sha => blob_sha } ], 
                                   {:base_tree => sha_base_tree }).sha
commit_message = "Committed via Octokit!"
sha_new_commit = github.create_commit(repo, commit_message, sha_new_tree, sha_latest_commit).sha
updated_ref = github.update_ref(repo, ref, sha_new_commit)
puts updated_ref
```
