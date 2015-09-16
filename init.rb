#Add rock-debs 
Autoproj.configuration_option 'use_deb', 'boolean',
	:default => 'yes',
	:doc => ["Add Rock-Debian-Repo?",
	"Some cool text telling you, you WANT to do this :-)"]

Autoproj.configuration_option 'release', 'string',
    :default => 'master',
    :doc => ["Which Rock-Release do you want to use?",
    "Possibilities are currently 'master'"]
Autoproj.configuration_option 'distribution', 'string',
    :default => 'vivid',
    :doc => ["Which distribution are you using?",
    "There are builds for 'jessie' (Debian), 'wheezy' (Debian), 'trusty' (Ubuntu), 'vivid' (Ubuntu)"]


#the actural settings if enabled
if (Autoproj.user_config('use_deb')) then
	Autobuild.env_add_path('PATH','/opt/rock/include')
	Autobuild.env_add_path('PATH','/opt/rock/share')
	Autobuild.env_add_path('CMAKE_PREFIX_PATH','/opt/rock')
	Autobuild.env_add_path('PKG_CONFIG_PATH','/opt/rock/lib/pkgconfig')
	Autobuild.env_add_path('RUBYLIB','/opt/rock/lib/ruby/1.9.1/')
	Autobuild.env_add_path('PATH','/opt/rock/lib/ruby/1.9.1/x86_64-linux')
	Autobuild.env_add_path('OROGEN_PLUGIN_PATH','/opt/rock/share/orogen/plugins')
	Autobuild.env_add_path('RUBYLIB','/opt/rock/lib/ruby/1.9.1/i686-linux')
		if !File.exist?("/etc/apt/sources.list.d/rock.list")
		system("sudo sh -c \"echo 'deb http://rimres-gcs2-u/release/#{Autoproj.user_config('release')} #{Autoproj.user_config('distribution')} main' > /etc/apt/sources.list.d/rock.list\"")
		system("wget http://rimres-gcs2-u/conf/Rock-debian.gpg.key")
		system("sudo apt-key add Rock-debian.gpg.key < Rock-debian.gpg.key") 
		system("sudo apt-get update > /dev/null")
		Autoproj.message "You need to run source env.sh before changes take effect"
	end
end
