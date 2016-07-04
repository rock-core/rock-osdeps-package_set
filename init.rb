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

Autoproj.configuration_option 'release', 'string',
    :default => 'master',
    :possible_answers => ['master'],
    :doc => ["Which Rock-Release do you want to use?",
    "Possibilities are currently 'master'"]

Autoproj.configuration_option 'distribution', 'string',
    :default => 'vivid',
    :possible_answers => ['jessie','wheezy','trusty','vivid'],
    :doc => ["Which distribution do you use?",
    "There are builds for 'jessie' (Debian), 'wheezy' (Debian), 'trusty' (Ubuntu), 'vivid' (Ubuntu)",
    "Which distribuion do you use?"]

Autoproj.user_config('DEB_USE') # To have a reasonable order of questions

Autoproj.configuration_option 'DEB_AUTOMATIC', 'boolean',
    :default => 'no',
    :doc => ["Do you want the installation be done automatically?",
    "This installation uses sudo and may ask for your password",
    "You can do the installation yourself with:",
    #"sudo sh -c \"echo 'deb http://rimres-gcs2-u/release/#{Autoproj.user_config('release')} #{Autoproj.user_config('distribution'    )} main' > /etc/apt/sources.list.d/rock.list\"",
    "sudo sh -c \"echo 'deb http://rimres-gcs2-u/release/#{Autoproj.user_config('ROCK_SELECTED_FLAVOR')} #{Autoproj.user_config('distribution'    )} main' > /etc/apt/sources.list.d/rock.list\"",
    "wget http://rimres-gcs2-u/conf/Rock-debian.gpg.key",
    "sudo apt-key add Rock-debian.gpg.key < Rock-debian.gpg.key",
    "rm Rock-debian.gpg.key",
    "sudo apt-get update > /dev/null",
    "##########################################################",
    "This installation uses sudo and may ask for your password",
    "Install automatically?"]


#the actural settings if enabled
if Autoproj.user_config('DEB_USE')
    architecture = "#{`gcc -print-multiarch`}".strip
    #release = Autoproj.user_config('release')
    release = Autoproj.user_config('ROCK_SELECTED_FLAVOR')

    require 'rbconfig'
    release_install_dir = "/opt/rock/#{release}"
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
    Autoproj.message "You need to run source env.sh before changes take effect"
end

if Autoproj.user_config('DEB_AUTOMATIC')
    if !File.exist?("/etc/apt/sources.list.d/rock.list")
        system("sudo sh -c \"echo 'deb http://rimres-gcs2-u/release/#{Autoproj.user_config('release')} #{Autoproj.user_config('distribution')} main' > /etc/apt/sources.list.d/rock.list\"")
        system("wget http://rimres-gcs2-u/conf/Rock-debian.gpg.key > /dev/null")
        system("sudo apt-key add Rock-debian.gpg.key < Rock-debian.gpg.key > /dev/null")
        system("rm Rock-debian.gpg.key")
        system("sudo apt-get update > /tmp/autoproj-update.log")
    end
end

if (!Autoproj.user_config('DEB_USE')) then
  Autoproj.message "Please remove the rock-osdeps-Package from your autoproj/manifest"
end

