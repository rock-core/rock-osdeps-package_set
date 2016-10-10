#Add rock-debs
Autoproj.configuration_option 'DEB_USE', 'boolean',
	:default => 'yes',
	:doc => ["This enables the usage of precompiled Debian-Packages.",
    "Every package you enter into your manifest will be downloaded and compiled the 'usual' way,",
    "so you still have all posibilities left to develop on all packages.",
    "The installed packages will be stored in /opt/rock/<rock-debian-release>/",
    "You will be later asked to select the rock debian release.",
    "Use rock debian packages?"]

Autoproj.configuration_option 'DEB_USE_UNAVAILABLE', 'string',
        :default => 'ok',
        :doc => "Debian packages are not provided for your operating system: #{Autoproj::OSDependencies.operating_system}"

#the actual settings if enabled
if Autoproj.user_config('DEB_USE')
    distribution,release = Autoproj::OSDependencies.operating_system
    current_release_name = nil
    ['jessie','trusty','xenial'].each do |release_name|
        if release.include?(release_name)
            current_release_name = release_name
            break
        end
    end

    if current_release_name
        if ["xenial"].include?(current_release_name)
            Autoproj.env_set "TYPELIB_CXX_LOADER","castxml"
        end

        Autoproj.configuration_option 'distribution', 'string',
            :default => current_release_name,
            :possible_answers => ['trusty','xenial'],
            :doc => ["Which distribution do you use?",
            "There are builds for 'jessie' (Debian), 'trusty' (Ubuntu), 'xenial' (Ubuntu)",
            "Which distribution do you use?"]

        Autoproj.configuration_option 'debian_release', 'string',
            :default => 'master-16.08',
            :possible_answers => ['master-16.07','master-16.08'],
            :doc => ["Select the rock debian release",
            "Use the default if you do not know better (currently there is only one anyway)"]

        Autoproj.configuration_option 'DEB_AUTOMATIC', 'boolean',
            :default => 'no',
            :doc => ["Do you want the installation be done automatically?",
            "This installation uses sudo and may ask for your password",
            "You can do the installation yourself with:",
            "echo 'deb http://rimres-gcs2-u/rock-releases/#{Autoproj.user_config('debian_release')} #{Autoproj.user_config('distribution')} main' | sudo tee /etc/apt/sources.list.d/rock.list",
            "wget http://rimres-gcs2-u/rock-devel/conf/Rock-debian.gpg.key",
            "sudo apt-key add Rock-debian.gpg.key < Rock-debian.gpg.key",
            "rm Rock-debian.gpg.key",
            "sudo apt-get update > /dev/null",
            "##########################################################",
            "This installation uses sudo and may ask for your password",
            "Install automatically?"]


        architecture = "#{`gcc -print-multiarch`}".strip
        debian_architecture = "#{`dpkg --print-architecture`}".strip
        flavor = Autoproj.user_config('ROCK_SELECTED_FLAVOR')
        if flavor != "master"
            Autoproj.warn "Debian packages are currently only available for the 'master' release, but you are using 'stable' release"
            Autoproj.warn "So either choose to not using debian packages, or switch to release 'master', e.g., with 'autoproj reconfigure'"
            exit 0
        end

        require 'rbconfig'
        Autoproj::OSDependencies.suffixes << "#{Autoproj.user_config('debian_release')}-#{debian_architecture}"
        release_install_dir = "/opt/rock/#{Autoproj.user_config('debian_release')}"
        rock_ruby_archdir = RbConfig::CONFIG['archdir'].gsub("/usr", release_install_dir)
        rock_ruby_vendordir =File.join(release_install_dir,"/lib/ruby/vendor_ruby")
        rock_ruby_vendorarchdir = RbConfig::CONFIG['vendorarchdir'].gsub("/usr", release_install_dir)
        rock_ruby_sitedir = RbConfig::CONFIG['sitedir'].gsub("/usr", release_install_dir)
        rock_ruby_sitearchdir = RbConfig::CONFIG['sitearchdir'].gsub("/usr", release_install_dir)
        rock_ruby_libdir = RbConfig::CONFIG['rubylibdir'].gsub("/usr", release_install_dir)

        Autobuild.env_add_path('PATH',File.join(release_install_dir,"bin"))
        Autobuild.env_add_path('CMAKE_PREFIX_PATH',release_install_dir)
        Autobuild.env_add_path('PKG_CONFIG_PATH',File.join("/usr/share/","pkgconfig"))
        Autobuild.env_add_path('PKG_CONFIG_PATH',File.join("/usr/lib/","pkgconfig"))
        Autobuild.env_add_path('PKG_CONFIG_PATH',File.join("/usr/lib/",architecture,"pkgconfig"))
        Autobuild.env_add_path('PKG_CONFIG_PATH',File.join(release_install_dir,"lib","pkgconfig"))
        Autobuild.env_add_path('PKG_CONFIG_PATH',File.join(release_install_dir,"lib",architecture, "pkgconfig"))
        Autobuild.env_add_path('PKG_CONFIG_PATH',File.join(ENV['AUTOPROJ_CURRENT_ROOT'],"install","lib","pkgconfig"))

        # RUBY SETUP
        Autobuild.env_add_path('RUBYLIB',rock_ruby_archdir)
        Autobuild.env_add_path('RUBYLIB',rock_ruby_vendordir)
        Autobuild.env_add_path('RUBYLIB',rock_ruby_vendorarchdir)
        Autobuild.env_add_path('RUBYLIB',rock_ruby_sitedir)
        Autobuild.env_add_path('RUBYLIB',rock_ruby_sitearchdir)
        Autobuild.env_add_path('RUBYLIB',rock_ruby_libdir)

        # Needed for qt
        Autobuild.env_add_path('RUBYLIB',File.join(rock_ruby_archdir.gsub(RbConfig::CONFIG['RUBY_PROGRAM_VERSION'],'')) )
        Autobuild.env_add_path('RUBYLIB',File.join(release_install_dir,"/lib/ruby/vendor_ruby/standard"))
        Autobuild.env_add_path('RUBYLIB',File.join(release_install_dir,"/lib/ruby/vendor_ruby/core"))

        Autobuild.env_add_path('RUBYLIB',File.join(release_install_dir,"/lib/ruby"))
        Autobuild.env_add_path('RUBYLIB',File.join(release_install_dir,"lib",architecture, "ruby"))

        # Runtime setup
        Autobuild.env_add_path('LD_LIBRARY_PATH',File.join(release_install_dir,"lib"))
        Autobuild.env_add_path('LD_LIBRARY_PATH',File.join(release_install_dir,"lib",architecture))

        # Compile time setup -- prefer locally installed packages over debian packages
        Autobuild.env_add_path('LIBRARY_PATH',File.join(release_install_dir,"lib"))
        Autobuild.env_add_path('LIBRARY_PATH',File.join(ENV['AUTOPROJ_CURRENT_ROOT'],"install","lib"))
        Autobuild.env_add_path('LIBRARY_PATH',File.join(ENV['AUTOPROJ_CURRENT_ROOT'],"install","lib",architecture))

        Autobuild.env_add_path('OROGEN_PLUGIN_PATH', File.join(release_install_dir,"/share/orogen/plugins"))
        Autobuild.env_add_path('TYPELIB_RUBY_PLUGIN_PATH', File.join(release_install_dir,"/share/typelib/ruby"))
        # gui/vizkit3d specific settings
        Autobuild.env_add_path('QT_PLUGIN_PATH', File.join(release_install_dir, "/lib/qt"))
        Autobuild.env_add_path('VIZKIT_PLUGIN_RUBY_PATH', File.join(release_install_dir, "/lib/vizkit"))
        Autobuild.env_add_path('VIZKIT_PLUGIN_RUBY_PATH', File.join(release_install_dir, "/lib"))
        Autobuild.env_add_path('OSG_FILE_PATH', File.join(release_install_dir, "/share/vizkit"))
        # Roby plugins: base/scripts, syskit
        ["rock/roby_plugin.rb", "syskit/roby_app/register_plugin.rb"].each do |roby_plugins|
            Autobuild.env_add_path('ROBY_PLUGIN_PATH', File.join(rock_ruby_vendordir, roby_plugins))
        end

        shell_extension = nil
        if ENV['SHELL'].include?('/zsh')
            shell_extension = File.join(release_install_dir,"share/scripts/shell/zsh")
        elsif ENV['SHELL'].include?('/bash')
            shell_extension = File.join(release_install_dir,"share/scripts/shell/bash")
        elsif ENV['SHELL'].include?('/sh')
            shell_extension = File.join(release_install_dir,"share/scripts/shell/sh")
        end

        if shell_extension and File.exist?(shell_extension)
            Autobuild.env_source_file(shell_extension)
        end

        Autoproj.message "You need to run source env.sh before changes take effect"
    else
        Autoproj.user_config('DEB_USE_UNAVAILABLE')
    end

    if Autoproj.user_config('DEB_AUTOMATIC')
        apt_rock_list_file = "/etc/apt/sources.list.d/rock.list"
        apt_source = "deb http://rimres-gcs2-u/rock-releases/#{Autoproj.user_config('debian_release')} #{Autoproj.user_config('distribution')} main"
        update = false
        if !File.exist?(apt_rock_list_file)
            update = true
        else
            File.open(apt_rock_list_file,"r") do |f|
                apt_source_existing = f.gets
                regexp = Regexp.new(apt_source)
                if !regexp.match(apt_source_existing)
                    Autoproj.message "  Existing apt source needs update: #{apt_source_existing}"
                    Autoproj.message "  Changing to: #{apt_source}"
                    update = true
                    Autoproj.warn "    You switched to using a new debian release, so please trigger a rebuild after completing this configuration"
                end
            end
        end
        if update
            if !system("echo #{apt_source} | sudo tee #{apt_rock_list_file}")
                Autoproj.warn "Failed to install apt source: #{apt_source}"
            else
                Autoproj.message " Installing Rock key"
                key_url = "http://rimres-gcs2-u/rock-devel/conf/Rock-debian.gpg.key"
                if !system("wget -q #{key_url}")
                    Autoproj.warn "Retrieving key from: #{key_url} failed"
                else
                    system("sudo apt-key add Rock-debian.gpg.key < Rock-debian.gpg.key > /dev/null")
                    system("rm Rock-debian.gpg.key")
                end
                Autoproj.message " Updating package source -- this can take some time"
                system("sudo apt-get update > /tmp/autoproj-update.log")
            end
        end
    end
else
  Autoproj.message "Use of rock debian packages is deactivated. (Remove the rock-osdeps-Package from your autoproj/manifest to deactivate this message)"
end

