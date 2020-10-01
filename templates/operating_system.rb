# The original file has been extracted from rubygems-integration with the
# following copyrigh

# Copyright: 2012-2014 Antonio Terceiro <terceiro@debian.org>
# License: Expat
#  Permission is hereby granted, free of charge, to any person obtaining
#  a copy of this software and associated documentation files (the
#  "Software"), to deal in the Software without restriction, including
#  without limitation the rights to use, copy, modify, merge, publish,
#  distribute, sublicense, and/or sell copies of the Software, and to
#  permit persons to whom the Software is furnished to do so, subject to
#  the following conditions:
#  .
#  The above copyright notice and this permission notice shall be included
#  in all copies or substantial portions of the Software.
#  .
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
#  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
#  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
#  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Additional modifications have been made to this file by Thomas Roehr <thomas.roehr@dfki.de>
# to permit the injection of paths via the environment variable RUBYGEMS_INTEGRATION_EXTRA_PATHS

# Generated from <%= File.expand_path(template_file) %>
unless ENV['DEBIAN_DISABLE_RUBYGEMS_INTEGRATION']

class << Gem
  OPERATING_SYSTEM_DEFAULTS = {
    :ssl_ca_cert => '/etc/ssl/certs/ca-certificates.crt'
  }

  alias :upstream_default_dir :default_dir
  def default_dir
    File.join('/', 'var', 'lib', 'gems', Gem::ConfigMap[:ruby_version])
  end

  alias :upstream_default_bindir :default_bindir
  def default_bindir
    File.join('/', 'usr', 'local', 'bin')
  end

  alias :upstream_default_path :default_path
  def default_path

    # FIXME remove (part of) this after we get rid of ruby 2.1 and 2.2
    extra_path = nil
    if RbConfig::CONFIG['ruby_version'] == '2.1.0'
      extra_path = File.join('/usr/share/rubygems-integration', '2.1')
    elsif RbConfig::CONFIG['ruby_version'] == '2.2.0'
      extra_path = File.join('/usr/share/rubygems-integration', '2.2')
    end

    arch = Gem::ConfigMap[:arch]
    api_version = Gem::ConfigMap[:ruby_version]

    extra_gem_paths = []
    if env_gem_paths = ENV['RUBYGEMS_INTEGRATION_EXTRA_PATHS']
        env_gem_paths.split(":").each do |path|
            extra_gem_paths << path if File.exists?(path)
        end
    end

    upstream_default_path + extra_gem_paths + [
      "/usr/lib/#{arch}/rubygems-integration/#{api_version}",
      File.join('/usr/share/rubygems-integration', api_version),
      extra_path,
      '/usr/share/rubygems-integration/all'
    ].compact
  end

end

if RUBY_VERSION >= '2.1' then
  class << Gem::BasicSpecification

    alias :upstream_default_specifications_dir :default_specifications_dir
    def default_specifications_dir
      File.join(Gem.upstream_default_dir, "specifications", "default")
    end

  end
end

end
