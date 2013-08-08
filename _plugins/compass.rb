# _plugins/compass.rb
#
# Jekyll Generator for SCSS
#
# (File paths in this description relative to jekyll project root directory)
# Place this file in ./_plugins
# Config file placed in ./_sass/config.rb
# Place .scss files in ./_scss/sass unless changed in config.rb
# Compiles .scss files in ./_scss to .css files in whatever directory you indicated in your config
#
 
require 'sass'
require 'pathname'
require 'compass'
require 'compass/exec'
 
module Jekyll
  class CompassGenerator < Generator
    safe true
 
    def generate(site)
      Dir.chdir File.expand_path('../_sass', File.dirname(__FILE__)) do
        Compass::Exec::SubCommandUI.new(%w(compile)).run!
      end
    end
  end
end