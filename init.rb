#Add rock-debs
Autoproj.configuration_option 'DEB_USE', 'boolean',
	:default => 'yes',
	:doc => ["Add Rock-Debian-Repo?",
	"This enables the precompiled Debian-Packages.",
    "Using this will save a lot of time as there are only very few packages you need to compile yourself.",
    "Every package you enter into your manifest will be downloaded and compiled the usual way,",
    "so you still have all posibilities left.",
    "The installed packages will be stored in /opt/rock/<flavour>/",
    "Use precompiles Packages?"]

#Autoproj.configuration_option 'release', 'string',
#    :default => 'master',
#    :possible_answers => ['master'],
#    :doc => ["Which Rock-Release do you want to use?",
#    "Possibilities are currently 'master'"]

Autoproj.user_config('DEB_USE') # To have a reasonable order of questions

#the actural settings if enabled
if Autoproj.user_config('DEB_USE')
    distribution,release = Autoproj::OSDependencies.operating_system
    current_release_name = nil
    ['jessie','trusty','vivid','xenial'].each do |release_name|
        if release.include?(release_name)
            current_release_name = release_name
            break
        end
    end

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
        :default => 'master-16.06',
        :possible_answers => ['master-16.06'],
        :doc => ["Select the master debian release",
        "Remain with the default if you do not know better (currently there is only one anyway)"]

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
    flavor = Autoproj.user_config('ROCK_SELECTED_FLAVOR')
    if flavor != "master"
        Autoproj.warn "Debian packages are currently only available for the 'master' release, but you are using 'stable' release"
        Autoproj.warn "So either choose to not using debian packages, or switch to release 'master', e.g., with 'autoproj reconfigure'"
        exit 0
    end

    require 'rbconfig'
    release_install_dir = "/opt/rock/master"
    rock_archdir = RbConfig::CONFIG['archdir'].gsub("/usr", release_install_dir)
    rock_rubylibdir = RbConfig::CONFIG['rubylibdir'].gsub("/usr", release_install_dir)

    Autobuild.env_add_path('PATH',File.join(release_install_dir,"bin"))
    Autobuild.env_add_path('CMAKE_PREFIX_PATH',release_install_dir)
    Autobuild.env_add_path('PKG_CONFIG_PATH',File.join(release_install_dir,"lib/pkgconfig"))
    Autobuild.env_add_path('PKG_CONFIG_PATH',File.join(release_install_dir,"lib",architecture, "pkgconfig"))
    Autobuild.env_add_path('RUBYLIB',rock_archdir)
    # Needed for qt
    Autobuild.env_add_path('RUBYLIB',File.join(rock_archdir.gsub(RbConfig::CONFIG['RUBY_PROGRAM_VERSION'],'')) )
    Autobuild.env_add_path('RUBYLIB',rock_rubylibdir)
    Autobuild.env_add_path('RUBYLIB',File.join(release_install_dir,"/lib/ruby/vendor_ruby/standard"))
    Autobuild.env_add_path('RUBYLIB',File.join(release_install_dir,"/lib/ruby/vendor_ruby/core"))
    Autobuild.env_add_path('RUBYLIB',File.join(release_install_dir,"/lib/ruby/vendor_ruby"))
    Autobuild.env_add_path('RUBYLIB',File.join(release_install_dir,"/lib/ruby"))
    Autobuild.env_add_path('LD_LIBRARY_PATH',File.join(release_install_dir,"lib"))
    Autobuild.env_add_path('OROGEN_PLUGIN_PATH', File.join(release_install_dir,"/share/orogen/plugins"))
    Autobuild.env_add_path('TYPELIB_RUBY_PLUGIN_PATH', File.join(release_install_dir,"/share/typelib/ruby"))
    # gui/vizkit3d specific settings
    Autobuild.env_add_path('QT_PLUGIN_PATH', File.join(release_install_dir, "/lib/qt"))
    Autobuild.env_add_path('VIZKIT_PLUGIN_RUBY_PATH', File.join(release_install_dir, "/lib/vizkit"))
    Autobuild.env_add_path('VIZKIT_PLUGIN_RUBY_PATH', File.join(release_install_dir, "/lib"))
    Autobuild.env_add_path('OSG_FILE_PATH', File.join(release_install_dir, "/share/vizkit"))
    # Syskit/Roby through base/scripts
    Autobuild.env_add_path('ROBY_PLUGIN_PATH', File.join(release_install_dir, "lib/ruby/vendor_ruby/rock/roby_plugin.rb"))
    Autoproj.message "You need to run source env.sh before changes take effect"
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

if (!Autoproj.user_config('DEB_USE')) then
  Autoproj.message "Please remove the rock-osdeps-Package from your autoproj/manifest"
end

