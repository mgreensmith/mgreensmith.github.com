---
layout: post
title: "Speed up rbenv init via background rehashing"
description: ""
category: 
tags: [ruby, rbenv]
comments: true
---
For a long time, new local shell windows on my development machine have taken a painful 2+ seconds to load. It finally bothered me enough to look into it, and the major culprit turned out to be the ruby version manager `rbenv`. More specifically, the non-backgrounded `rbenv rehash` action that happens on every initialization.

<!--more-->
My `.zshrc` loads `rbenv` in the standard way: `eval "$(rbenv init -)"`, which takes a non-trivial 1.4 seconds to execute:

```
$ time eval "$(rbenv init -)"

real  0m1.392s
user  0m1.310s
sys 0m0.089s
```

Adding the `--no-rehash` flag to `rbenv init` speeds it up by a factor of 30:

```
$ time eval "$(rbenv init --no-rehash -)"

real  0m0.045s
user  0m0.025s
sys 0m0.023s
```

Skipping the rehash on shell load has few repercussions, since a rehash at this juncture is not really useful. Rehashing is only necessary after installing new gems, and you would perform this action manually, or you would use the excellent [rbenv-gem-rehash plugin](https://github.com/sstephenson/rbenv-gem-rehash) which would do it automatically. Additionally, this plugin will be deprecated soon, as the automatic rehash action has just landed in `rbenv` core via [rbenv issue #384](https://github.com/sstephenson/rbenv/issues/384).

However, if you still want to rehash on shell load, you can do so in a backgrounded action. I found this method buried in a [GitHub issue comment by Phillip Ridlen](https://github.com/carsomyr/rbenv-bundler/issues/33).

```
eval "$(rbenv init --no-rehash -)"
(rbenv rehash &) 2> /dev/null
```