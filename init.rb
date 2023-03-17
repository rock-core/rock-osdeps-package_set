distribution = nil
release = nil
if defined?(Autoproj::OSDependencies)
    distribution,release = Autoproj::OSDependencies.operating_system
elsif defined?(Autoproj::OSPackageResolver)
    distribution,release = Autoproj::OSPackageResolver.autodetect_operating_system
else
    raise "Unsupported Autoproj API: please inform the developer"
end

require_relative 'lib/rock-osdeps/package_selector'

#Add rock-debs
Autoproj.config.declare 'DEB_USE', 'boolean',
        :default => 'yes',
        :doc => ["Use rock debian packages ?",
          "This enables the usage of precompiled Debian-Packages.",
          "Every package you enter into your manifest will be downloaded and ",
          "compiled the 'usual' way, so you still have all posibilities left to ",
          "develop on all packages. The installed packages will be stored in ",
          "/opt/rock/<rock-debian-release>/. You will be later asked to select the rock",
          "debian release. So, use rock debian packages? "]

Autoproj.config.declare 'DEB_USE_UNAVAILABLE', 'string',
        :default => 'ok',
        :doc => "Debian packages are not provided for your operating system: #{distribution}, #{release}"

#the actual settings if enabled
if Autoproj.user_config('DEB_USE')
    current_release_name = nil
    ['jessie','squeeze','stretch','buster','trusty','xenial','bionic','focal'].each do |release_name|
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

        Autoproj.config.declare 'debian_release', 'string',
            :default => 'master-20.06',
            :possible_answers => Rock::DebianPackaging::Release.available,
            :doc => ["Which rock debian release should be used
            (available are: #{Rock::DebianPackaging::Release::available.sort.join(',')}) ?",
            "Use the default if you do not know better"]

        require_relative 'lib/rock-osdeps/release'
        release = Rock::DebianPackaging::Release.new(
                        Autoproj.user_config('debian_release'),
                        data_dir: File.join(__dir__,'data'))

        Autoproj.config.declare 'DEB_AUTOMATIC', 'boolean',
            :default => 'yes',
            :doc => ["Do you want the installation be done automatically?",
            "This installation uses sudo and may ask for your password",
            "You can do the installation yourself with:",
            "echo 'deb [arch=#{debian_architecture} trusted=yes] #{release.repo_url}/#{release.name} #{current_release_name} main' | sudo tee /etc/apt/sources.list.d/rock-#{release.name}.list",
            "wget -qO - #{release.public_key} | sudo apt-key add -",
            "sudo apt-get update > /dev/null",
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

        release.update_apt_list(current_release_name) if Autoproj.user_config('DEB_AUTOMATIC')
        begin
            Rock::DebianPackaging::PackageSelector.activate_release(release)
        rescue Exception => e
            puts "#{e} #{e.backtrace.join("\n\t")}"
            raise
        end
    else
        Autoproj.user_config('DEB_USE_UNAVAILABLE')
    end
else
  Autoproj.message "  Use of rock debian packages is deactivated. (Remove the rock-osdeps-Package from your autoproj/manifest to deactivate this message)"
  osdeps_file = File.join(__dir__, "rock-osdeps.osdeps")
  if File.exists?(osdeps_file)
      Autoproj.message "  Removing autogenerated osdeps file: #{osdeps_file}"
      FileUtils.rm osdeps_file
  end
end

