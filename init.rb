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

Autoproj.configuration_option 'DEB_AUTOMATIC', 'boolean',
    :default => 'yes',
    :doc => ["Do you want the installation be done automatically?",
    "This installation uses sudo and may ask for your password",
    "You can do the installation yourself with:",
    "sudo sh -c \"echo 'deb http://rimres-gcs2-u/release/#{Autoproj.user_config('release')} #{Autoproj.user_config('distribution'    )} main' > /etc/apt/sources.list.d/rock.list\"",
    "wget http://rimres-gcs2-u/conf/Rock-debian.gpg.key",
    "sudo apt-key add Rock-debian.gpg.key < Rock-debian.gpg.key",
    "rm Rock-debian.gpg.key",
    "sudo apt-get update > /dev/null",
    "##########################################################",
    "This installation uses sudo and may ask for your password",
    "Install automatically?"]


#the actural settings if enabled
if (Autoproj.user_config('DEB_USE') && Autoproj.user_config('DEB_AUTOMATIC')) then
	Autobuild.env_add_path('PATH',"/opt/rock/#{Autoproj.user_config('release')}/include")
	Autobuild.env_add_path('PATH',"/opt/rock/#{Autoproj.user_config('release')}/share")
	Autobuild.env_add_path('CMAKE_PREFIX_PATH',"/opt/rock/#{Autoproj.user_config('release')}")
	Autobuild.env_add_path('PKG_CONFIG_PATH',"/opt/rock/#{Autoproj.user_config('release')}/lib/pkgconfig")
	Autobuild.env_add_path('RUBYLIB',"/opt/rock/#{Autoproj.user_config('release')}/lib/ruby/#{RUBY_VERSION}/")
	Autobuild.env_add_path('PATH',"/opt/rock/#{Autoproj.user_config('release')}/lib/#{`gcc -dumpmachine`}/ruby/#{RUBY_VERSION}")
	Autobuild.env_add_path('OROGEN_PLUGIN_PATH',"/opt/rock/#{Autoproj.user_config('release')}/share/orogen/plugins")
	Autobuild.env_add_path('RUBYLIB',"/opt/rock/#{Autoproj.user_config('release')}/lib/ruby/#{RUBY_VERSION}/#{`gcc -dumpmachine`}")
		if !File.exist?("/etc/apt/sources.list.d/rock.list")
		system("sudo sh -c \"echo 'deb http://rimres-gcs2-u/release/#{Autoproj.user_config('release')} #{Autoproj.user_config('distribution')} main' > /etc/apt/sources.list.d/rock.list\"")
		system("wget http://rimres-gcs2-u/conf/Rock-debian.gpg.key > /dev/null")
		system("sudo apt-key add Rock-debian.gpg.key < Rock-debian.gpg.key > /dev/null") 
        system("rm Rock-debian.gpg.key")
		system("sudo apt-get update > /dev/null")
		Autoproj.message "You need to run source env.sh before changes take effect"
	end
end
if (!Autoproj.user_config('DEB_USE')) then
  Autoproj.message "You need to delete the rock-osdeps-Package from your autoproj/manifest"
end
