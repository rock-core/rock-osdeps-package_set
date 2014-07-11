#Add rock-debs 
Autoproj.configuration_option 'use_deb', 'boolean',
	:default => 'yes',
	:doc => ["Add Rock-Debian-Repo",
	"Some cool text telling you, you WANT to do this :-)"]


#the actural settings if enabled
if (Autoproj.user_config('use_deb')) then
	Autobuild.env_add_path('PATH','/opt/rock/include')
	Autobuild.env_add_path('PATH','/opt/rock/share')
	Autobuild.env_add_path('CMAKE_PREFIX_PATH','/opt/rock')
	Autobuild.env_add_path('PKG_CONFIG_PATH','/opt/rock/lib/pkgconfig')
	Autobuild.env_add_path('RUBYLIB','/opt/rock/lib/ruby/1.9.1/')
	Autobuild.env_add_path('PATH','/opt/rock/lib/ruby/1.9.1/x86_64-linux')
		if !File.exist?("/etc/apt/sources.list.d/rock.list")
		system("sudo sh -c \"echo 'deb http://download.opensuse.org/repositories/home:/roehr:/rock-robotics/xUbuntu_12.04/ /' > /etc/apt/sources.list.d/rock.list\"")
		system("wget http://download.opensuse.org/repositories/home:roehr:rock-robotics/xUbuntu_12.04/Release.key")
		system("sudo apt-key add - < Release.key") 
		system("sudo apt-get update > /dev/null")
		Autoproj.message "You need to run source env.sh before changes take effect"
	end
end
