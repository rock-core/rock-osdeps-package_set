distribution = nil
release = nil
if defined?(Autoproj::OSDependencies)
    distribution,release = Autoproj::OSDependencies.operating_system
elsif defined?(Autoproj::OSPackageResolver)
    distribution,release = Autoproj::OSPackageResolver.autodetect_operating_system
else
    raise "Unsupported Autoproj API: please inform the developer"
end

require_relative 'lib/package_selector'

#Add rock-debs
Autoproj.configuration_option 'DEB_USE', 'boolean',
        :default => 'yes',
        :doc => ["Use rock debian packages ?",
          "This enables the usage of precompiled Debian-Packages.",
          "Every package you enter into your manifest will be downloaded and ",
          "compiled the 'usual' way, so you still have all posibilities left to ",
          "develop on all packages. The installed packages will be stored in ",
          "/opt/rock/<rock-debian-release>/. You will be later asked to select the rock",
          "debian release. So, use rock debian packages? "]

Autoproj.configuration_option 'DEB_USE_UNAVAILABLE', 'string',
        :default => 'ok',
        :doc => "Debian packages are not provided for your operating system: #{distribution}, #{release}"

#the actual settings if enabled
if Autoproj.user_config('DEB_USE')
    current_release_name = nil
    ['jessie','squeeze','stretch','trusty','xenial','bionic'].each do |release_name|
        if release.include?(release_name)
            current_release_name = release_name
            break
        end
    end

    if current_release_name
        if ["trusty", "jessie"].include?(current_release_name)
            Autoproj.env_set "TYPELIB_CXX_LOADER","gccxml"
        else
            Autoproj.env_set "TYPELIB_CXX_LOADER","castxml"
        end

        architecture = "#{`gcc -print-multiarch`}".strip
        debian_architecture = "#{`dpkg --print-architecture`}".strip

        Autoproj.configuration_option 'debian_release', 'string',
            :default => 'master-20.01',
            :possible_answers => Rock::DebianPackaging::Release.available,
            :doc => ["Which rock debian release should be used
            (available are: #{Rock::DebianPackaging::Release::available.sort.join(',')}) ?",
            "Use the default if you do not know better"]

        require_relative 'lib/release'
        release = Rock::DebianPackaging::Release.new(
                        Autoproj.user_config('debian_release'),
                        data_dir: File.join(__dir__,'data'))

        Autoproj.configuration_option 'DEB_AUTOMATIC', 'boolean',
            :default => 'yes',
            :doc => ["Do you want the installation be done automatically?",
            "This installation uses sudo and may ask for your password",
            "You can do the installation yourself with:",
            "echo 'deb [arch=#{debian_architecture} trusted=yes] #{release.repo_url}/#{release.name} #{current_release_name} main' | sudo tee /etc/apt/sources.list.d/rock-#{release.name}.list",
            "sudo apt-get update > /dev/null",
            "wget -qO - #{release.public_key} | sudo apt-key add -",
            "##########################################################",
            "This installation uses sudo and may ask for your password",
            "Install automatically?"]

        begin
            flavor = Autoproj.user_config('ROCK_SELECTED_FLAVOR')
            if flavor != "master"
                Autoproj.warn "Debian packages are currently only available for the 'master' release, but you are using 'stable' release"
                Autoproj.warn "So either choose to not using debian packages, or switch to release 'master', e.g., with 'autoproj reconfigure'"
                exit 0
            end
        rescue Autoproj::ConfigError => e
            # rock-core has not been imported to set the flavor yet, thus define
            # the required flavor
            Autoproj.config.set('ROCK_SELECTED_FLAVOR','master')
        end

        require 'rbconfig'
        suffix = "#{release.name}-#{debian_architecture}"
        if defined?(Autoproj::OSDependencies)
            Autoproj::OSDependencies.suffixes << "#{release.name}-#{debian_architecture}"
        elsif defined?(Autoproj::OSPackageResolver)
            Autoproj.workspace.osdep_suffixes << suffix
        else
            raise "Unsupported Autoproj API: please inform the developer"
        end

        # identify the major.minor version of python
        python_version=
        if Autoproj.config.has_value_for?('python_version')
            python_version = Autoproj.config.get('python_version')
        else
            require 'open3'
            msg, status = Open3.capture2e("which python")
            if status.success?
                python_version=`python -c "import sys; version=sys.version_info[:3]; print('{0}.{1}'.format(*version))"`.strip
            end
        end

        Autoproj.info "Required releases: #{release.hierarchy}"
        release.hierarchy.each do |release_name|
            release_install_dir = "/opt/rock/#{release_name}"

            rock_ruby_archdir       = RbConfig::CONFIG['archdir'].gsub("/usr", release_install_dir)
            rock_ruby_vendordir     = File.join(release_install_dir,"/lib/ruby/vendor_ruby")
            rock_ruby_vendorarchdir = RbConfig::CONFIG['vendorarchdir'].gsub("/usr", release_install_dir)
            rock_ruby_sitedir       = RbConfig::CONFIG['sitedir'].gsub("/usr", release_install_dir)
            rock_ruby_sitearchdir   = RbConfig::CONFIG['sitearchdir'].gsub("/usr", release_install_dir)
            rock_ruby_libdir        = RbConfig::CONFIG['rubylibdir'].gsub("/usr", release_install_dir)

            Autobuild.env.add('PATH',File.join(release_install_dir,"bin"))
            Autobuild.env.add('CMAKE_PREFIX_PATH',File.join(release_install_dir))
            Autobuild.env.add('CMAKE_PREFIX_PATH',File.join(release_install_dir,"share/rock/cmake"))
            Autobuild.env.add('CMAKE_PREFIX_PATH',File.join(Autoproj.root_dir,"install"))
            Autobuild.env.add('CMAKE_PREFIX_PATH',File.join(Autoproj.root_dir,"install/share/rock/cmake"))
            Autobuild.env.add('PKG_CONFIG_PATH',File.join(release_install_dir,"lib",architecture, "pkgconfig"))
            Autobuild.env.add('PKG_CONFIG_PATH',File.join(release_install_dir,"lib","pkgconfig"))

            # RUBY SETUP
            Autobuild.env.add('RUBYLIB',rock_ruby_archdir)
            Autobuild.env.add('RUBYLIB',rock_ruby_vendordir)
            Autobuild.env.add('RUBYLIB',rock_ruby_vendorarchdir)
            Autobuild.env.add('RUBYLIB',rock_ruby_sitedir)
            Autobuild.env.add('RUBYLIB',rock_ruby_sitearchdir)
            Autobuild.env.add('RUBYLIB',rock_ruby_libdir)

            # Needed for qt
            Autobuild.env.add('RUBYLIB',File.join(rock_ruby_archdir.gsub(RbConfig::CONFIG['RUBY_PROGRAM_VERSION'],'')) )
            Autobuild.env.add('RUBYLIB',File.join(release_install_dir,"/lib/ruby/vendor_ruby/standard"))
            Autobuild.env.add('RUBYLIB',File.join(release_install_dir,"/lib/ruby/vendor_ruby/core"))

            Autobuild.env.add('RUBYLIB',File.join(release_install_dir,"lib",architecture, "ruby"))
            Autobuild.env.add('RUBYLIB',File.join(release_install_dir,"/lib/ruby"))

            # PYTHON SETUP
            if python_version
                Autobuild.env.add('PYTHONPATH', File.join(release_install_dir,"lib","python#{python_version}","site-packages"))
            end

            # Runtime setup
            Autobuild.env.add('LD_LIBRARY_PATH',File.join(release_install_dir,"lib",architecture))
            Autobuild.env.add('LD_LIBRARY_PATH',File.join(release_install_dir,"lib"))
            Autobuild.env.add('LD_LIBRARY_PATH',File.join(ENV['AUTOPROJ_CURRENT_ROOT'],"install","lib",architecture))
            Autobuild.env.add('LD_LIBRARY_PATH',File.join(ENV['AUTOPROJ_CURRENT_ROOT'],"install","lib"))

            # Compile time setup -- prefer locally installed packages over debian packages
            Autobuild.env.add('LIBRARY_PATH',File.join(release_install_dir,"lib",architecture))
            Autobuild.env.add('LIBRARY_PATH',File.join(release_install_dir,"lib"))
            Autobuild.env.add('LIBRARY_PATH',File.join(ENV['AUTOPROJ_CURRENT_ROOT'],"install","lib",architecture))
            Autobuild.env.add('LIBRARY_PATH',File.join(ENV['AUTOPROJ_CURRENT_ROOT'],"install","lib"))

            Autobuild.env.add('OROGEN_PLUGIN_PATH', File.join(release_install_dir,"/share/orogen/plugins"))
            Autobuild.env.add('OROGEN_PLUGIN_PATH', File.join(ENV['AUTOPROJ_CURRENT_ROOT'],"install","share","orogen","plugins"))
            Autobuild.env.add('TYPELIB_RUBY_PLUGIN_PATH', File.join(release_install_dir,"/share/typelib/ruby"))
            # gui/vizkit3d specific settings
            Autobuild.env.add('QT_PLUGIN_PATH', File.join(release_install_dir, "/lib/qt"))
            Autobuild.env.add('VIZKIT_PLUGIN_RUBY_PATH', File.join(release_install_dir, "/lib/vizkit"))
            Autobuild.env.add('VIZKIT_PLUGIN_RUBY_PATH', File.join(release_install_dir, "/lib"))
            Autobuild.env.add('OSG_FILE_PATH', File.join(release_install_dir, "/share/vizkit"))
            # Roby plugins: base/scripts, syskit
            ["rock/roby_plugin.rb", "syskit/roby_app/register_plugin.rb"].each do |roby_plugins|
                Autobuild.env.add('ROBY_PLUGIN_PATH', File.join(rock_ruby_vendordir, roby_plugins))
            end
            Autobuild.env.add('ROCK_BUNDLE_PATH', File.join(release_install_dir, "share/rock/bundles"))

            shell_extension = nil
            if ENV.has_key?('SHELL')
                if ENV['SHELL'].include?('/zsh')
                    shell_extension = File.join(release_install_dir,"share/scripts/shell/zsh")
                elsif ENV['SHELL'].include?('/bash')
                    shell_extension = File.join(release_install_dir,"share/scripts/shell/bash")
                elsif ENV['SHELL'].include?('/sh')
                    shell_extension = File.join(release_install_dir,"share/scripts/shell/sh")
                end
            else
                Autoproj.warn "Failed to identify active shell type, "
                    "cannot select a shell extension "
                    " from #{File.join(release_install_dir,'share/scripts/shell')}"
            end

            if shell_extension and File.exist?(shell_extension)
                Autobuild.env_source_file(shell_extension)
            end
        end
        Autobuild.env_remove_path('PATH',File.join(ENV['AUTOPROJ_CURRENT_ROOT'],"install","bin"))
        Autobuild.env.add('PATH',File.join(ENV['AUTOPROJ_CURRENT_ROOT'],"install","bin"))

        Autobuild.env.add('PKG_CONFIG_PATH',File.join("/usr/share/","pkgconfig"))
        Autobuild.env.add('PKG_CONFIG_PATH',File.join("/usr/lib/","pkgconfig"))
        Autobuild.env.add('PKG_CONFIG_PATH',File.join("/usr/lib/",architecture,"pkgconfig"))
        Autobuild.env.add('PKG_CONFIG_PATH',File.join(ENV['AUTOPROJ_CURRENT_ROOT'],"install","lib","pkgconfig"))
    else
        Autoproj.user_config('DEB_USE_UNAVAILABLE')
    end

    if Autoproj.user_config('DEB_AUTOMATIC')
        release.hierarchy.each do |release_name|
            Autoproj.info "Activating release: #{release_name}"
            apt_rock_list_file = "/etc/apt/sources.list.d/rock-#{release_name}.list"
            apt_source = "[arch=#{debian_architecture} trusted=yes] #{release.repo_url}/#{release.name} #{current_release_name} main"
            update = false
            if !File.exist?(apt_rock_list_file)
                update = true
            else
                File.open(apt_rock_list_file,"r") do |f|
                    apt_source_existing = f.gets
                    regexp = Regexp.new( Regexp.escape(apt_source) )
                    if !regexp.match(apt_source_existing)
                        Autoproj.message "  Existing apt source needs update: #{apt_source_existing}"
                        Autoproj.message "  Changing to: #{apt_source}"
                        update = true
                        Autoproj.warn "  You switched to using a new debian release, so please trigger a rebuild after completing this configuration"
                    end
                end
            end

            if update
                if !system("echo deb #{apt_source} | sudo tee #{apt_rock_list_file}")
                    Autoproj.warn "Failed to install apt source: #{apt_source}"
                else
                    Autoproj.message "Adding deb-src entry"
                    system("echo deb-src #{apt_source} | sudo tee -a #{apt_rock_list_file}")

                    if release.public_key
                        Autoproj.message "Adding public key for rock-robotics"
                        if !system("wget -qO - #{release.public_key} | sudo apt-key add -")
                            Autoproj.warn "Failed to add public key for rock-robotics"
                        end
                    end

                    Autoproj.message "  Updating package source -- this can take some time"
                    system("sudo apt-get update > /tmp/autoproj-update.log")

                end
            end
        end

        Autoproj.env_set('ROCK_DEB_RELEASE_NAME',release.name)
        hierarchy = ""
        release.hierarchy.each do |release_name|
            hierarchy += "#{release.name}:#{release.repo_url}/#{release.name};"
        end
        Autoproj.env_set('ROCK_DEB_RELEASE_HIERARCHY',hierarchy)
    end

    Rock::DebianPackaging::PackageSelector.activate_release(release)
else
  Autoproj.message "  Use of rock debian packages is deactivated. (Remove the rock-osdeps-Package from your autoproj/manifest to deactivate this message)"
  osdeps_file = File.join(__dir__, "rock-osdeps.osdeps")
  if File.exists?(osdeps_file)
      Autoproj.message "  Removing autogenerated osdeps file: #{osdeps_file}"
      FileUtils.rm osdeps_file
  end
end

