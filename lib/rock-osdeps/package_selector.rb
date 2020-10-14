require 'yaml'
require 'autoproj'
require 'erb'
require_relative 'release'

module Rock
module DebianPackaging

class PackageSelector
    attr_reader :osdeps
    attr_reader :pkg_to_deb
    attr_reader :deb_to_pkg
    attr_reader :blacklist

    attr_reader :rdepends_cache_file

    DEFAULT_INACTIVE_SELECTION = "rock-osdeps.inactive"

    def initialize(osdeps_file = nil)
        @osdeps = {}
        if osdeps_file
            load_osdeps_file(osdeps_file)
        end
        @rdepends_cache_file = File.join(PACKAGE_SET_DIR,".rdepends-cache.yml")
    end

    # Load the osdeps file considering only the relevant entries
    # for this platform
    # @param osdeps_file [String] The file to load
    # @param allow_override [allow_override] Allow entries in the osdeps files
    #     to override each other
    def load_osdeps_file(osdeps_file, allow_override: true)
        osdeps = YAML.load_file(osdeps_file)

        @pkg_to_deb ||= {}
        @deb_to_pkg ||= {}
        @reverse_dependencies_map ||= {}

        distribution, release = PackageSelector.operating_system

        compact_osdeps = {}
        return unless osdeps

        osdeps.each do |pkg_name, osdeps_list|
            pkgs = nil
            if osdeps_list.has_key?(distribution.first)
                pkgs = osdeps_list[distribution.first]
            elsif osdeps_list.has_key?(distribution.join(","))
                pkgs = osdeps_list[distribution.join(",")]
            end
            if !pkgs || pkgs.empty?
                Autoproj.warn "#{self.class}::#{__method__}: #{osdeps_file} does not contain information" \
                    " for package '#{pkg_name}' and distribution '#{distribution.join(",")}'"
                next
            end
            pkgs.each do |key, debian_pkg_name|
                if matching_release?(key, release)
                    if @pkg_to_deb.has_key?(pkg_name)
                        if not allow_override
                            raise RuntimeError, "#{self.class}::#{__method__}: loading" \
                                " #{osdeps_file} would override entry for #{pkg_name}," \
                                " existing '#{@pkg_to_deb[pkg_name]}'," \
                                " new '#{debian_pkg_name}'"
                        else
                            Autoproj.info "#{self.class}::#{__method__}: loading#{osdeps_file} overrides existing entry for #{pkg_name}" \
                                " existing '#{@pkg_to_deb[pkg_name]}'," \
                                " new '#{debian_pkg_name}'"
                        end
                    end
                    @pkg_to_deb[pkg_name] = debian_pkg_name
                    @deb_to_pkg[debian_pkg_name] = [pkg_name]

                    compact_osdeps[pkg_name] = Hash.new
                    compact_osdeps[pkg_name]['default'] = debian_pkg_name
                end
            end
        end
        @osdeps = @osdeps.merge(compact_osdeps)
    end

    # Test if a given keyentry in a osdeps file matches the current os
    def matching_release?(key, active_release_names)
        supported_releases = key.split(",")
        # key - from osdeps file, e.g., "18.04,bionic,beaver,default"
        # release - from autoproj's autodetection ["18.04", "18.04.5", "lts", "bionic", "beaver", "default"]

        active_release_names.each do |name|
            if name == "default"
                next
            end

            if supported_releases.include?(name)
                return true
            end
        end
        false
    end

    # Retrieve the osdeps file for this release and the current architecture
    # @param release_name [String] name of the release (should be a key in the
    #   releases.yml file)
    # @return [String] path to the release file
    def self.release_osdeps_file(release_name, data_dir: nil)
        if !data_dir
            raise ArgumentError, "PackageSelector.release_osdeps_file: data directory not provided"
        end
        release_file =
            File.join(data_dir,"#{release_name}-#{Release.architecture}.yml")
        if !File.exist?(release_file)
            raise ArgumentError, "#{self.class}::#{__method__}: rock release '#{release_name}' has no osdeps file for the architecture '#{Release.architecture}' -- #{File.absolute_path(release_file)} missing"
        end
        release_file
    end

    # Activate the package selection for a particular release - including the
    # releases it depends upon
    # @param release [Release] Release instance
    # @param data_dir [String] Path to the data directory, where the osdeps
    #     files and the releases spec file (releases.yml) resides
    # @param output_dir [String] Path to the directory for the dynamically generated
    #     osdeps file - the one that is finally taken into account by autoproj
    # @return [PackageSelector] A package selector instance containing
    #     information about blacklisted and used packages
    def self.activate_release(release,
                              output_dir: PACKAGE_SET_DIR
                             )
        Rock::DebianPackaging::PackageSelector::activate_releases(release.hierarchy,
                                                                  data_dir: release.data_dir,
                                                                  spec_data: release.spec,
                                                                  output_dir: output_dir,
                                                                  ws: release.ws)
    end

    # Activate a list of releases, loads the blacklist from the current
    # workspace's config_dir and writes the temporary active osdeps file
    # @param data_dir [String] Path to the data directory, where the osdeps
    #     files and the releases spec file (releases.yml) resides
    # @param output_dir [String] Path to the directory for the dynamically generated
    #     osdeps file - the one that is finally taken into account by autoproj
    # @return [PackageSelector] A package selector instance containing
    #     information about blacklisted and used packages
    def self.activate_releases(release_names,
                               data_dir: nil,
                               spec_file: nil,
                               spec_data: nil,
                               ws: Autoproj.workspace,
                               output_dir: PACKAGE_SET_DIR,
                               auto_update: true
                            )
        ps = Rock::DebianPackaging::PackageSelector.new
        package_list_updated = false

        # Cleanup existing autogenerated envsh
        envsh = File.join(__dir__, "..", Release::DEFAULT_ENV_SH)
        FileUtils.rm_rf envsh if File.exist?(envsh)

        release_names.each do |release_name|
            release = Rock::DebianPackaging::Release.new(release_name,
                                                         data_dir: data_dir,
                                                         spec_file: spec_file,
                                                         spec_data: spec_data,
                                                         ws: ws)
            release.update_env
            package_list_updated ||= release.update()

            ps.load_osdeps_file release_osdeps_file(release_name, data_dir: data_dir)
        end

        if package_list_updated && auto_update
            logfile = "/tmp/autoproj-update-rock-osdeps.log"
            Autoproj.message "This rock release has new packages. Calling " \
                "apt-get update to retrieve package information -- this can take some" \
                "time (see #{logfile})"
            system("sudo apt-get update > #{logfile}")
        end
        filtered_osdeps, disabled_pkgs = ps.load_blacklist(ws: ws)
        File.open( File.join(PACKAGE_SET_DIR, DEFAULT_INACTIVE_SELECTION),"w") do |file|
            file.write(disabled_pkgs.to_yaml)
        end
        ps.write_osdeps_file(filtered_osdeps, disabled_pkgs, output_dir: output_dir)

        ps.activate_package_env(filtered_osdeps, ws: ws)
        ps.activate_rubygems_integrations(filtered_osdeps, ws: ws)
        ps
    end

    # Retrieve the operating system
    def self.operating_system(ws: Autoproj.workspace)
        if defined?(Autoproj::OSDependencies)
            Autoproj::OSDependencies.operating_system
        elsif defined?(Autoproj::OSPackageResolver)
            ws.os_package_resolver.operating_system
        else
            raise "#{self.class}::#{__method__}: unsupported Autoproj API: please inform the developer"
        end
    end

    # To allow the `gem` command to work properly within a workspace, the
    # available rubygems hook has to be used, i.e. writing
    #     rubygems/defaults/operating_system.rb
    # 
    # The package rubygems-integration already does this, but has not way to
    # inject a custom path. Therefore, we inject our own slightly modified
    # version, such that paths can be added via the environmental variable
    #     RUBYGEMS_INTEGRATION_EXTRA_PATHS
    #
    # Now to activate gems selectively in a workspace, a subfolder (here .rubygems-integration)
    # is used as main integration path, which receives links into the file
    # system.
    #
    # Example: to activate a particular gemspec lying in the release
    #     folder, e.g., /opt/rock/master-20.06/rock-master-20.06-ruby-rice/share/rubygems-integration/all/specifications/rice-2.2.0.gemspec
    # will be referred from 
    #     /yourworkspace/.rubygems-integration/all/specification/rice-2.0.0.gemspec
    # while the environment needs to be setup, so that the path can be injected
    # via the operating_system.rb hook into gems:
    #    export  RUBYGEMS_INTEGRATION_EXTRA_PATHS=/yourworkspace/.rubgems-integration/all:/yourworkspace>/.rubgems-integration/2.5.0
    #
    # The list of gems depends upon the correspondingly activated packages
    # (filtered_osdeps), according to the settings in deb_blacklist.yml
    def activate_rubygems_integrations(filtered_osdeps, ws: Autoproj.workspace)
        # Setup integration directories
        rubygems_integration_dir = File.expand_path(File.join(ws.root_dir, ".rubygems-integration"))
        rubygems_integration_libdir = File.join(rubygems_integration_dir, "lib")
        FileUtils.mkdir_p rubygems_integration_libdir unless File.directory?(rubygems_integration_libdir)

        rubygems_integration_alldir = File.join(rubygems_integration_dir, "all")
        FileUtils.mkdir_p rubygems_integration_alldir unless File.directory?(rubygems_integration_alldir)

        # With the template file we inject
        # the option to add a path to RUBYGEMS_INTEGRATION_EXTRA_PATHS
        template_file =
            File.join(PACKAGE_SET_DIR,"templates","operating_system.rb")

        template = ERB.new(File.read(template_file), nil, "%<>")
        rendered = template.result(binding)

        target_dir =
            File.join(rubygems_integration_libdir,"rubygems","defaults")
        FileUtils.mkdir_p target_dir unless File.directory?(target_dir)

        target_path = File.join(target_dir, "operating_system.rb")
        File.open(target_path, "w") do |io|
            io.write(rendered)
        end

        ws.env.add_path("RUBYLIB", rubygems_integration_libdir)
        integration_paths = []
        Dir.glob(File.join(rubygems_integration_dir,"*","specifications")).each do |dir|
            FileUtils.rm_rf dir
        end
        Dir.glob(File.join(rubygems_integration_dir,"*","gems")).each do |dir|
            FileUtils.rm_rf dir
        end
        each_gem_spec(filtered_osdeps) do |gem_spec|
            if gem_spec =~ /(\/opt\/rock\/.*)\/share\/rubygems-integration\/(.*)\/specifications\/(.*).gemspec/
                pkg_content = $1
                ruby_version = $2
                versioned_gem = $3

                integration_paths << File.join(rubygems_integration_dir,ruby_version)

                # Link gemspec into local rubygems-integration folder
                # This folder has to be known to rubygems via
                # rubygems/default/operating_system.rb -- which is now patched
                # so that we can use an environmental setting of RUBYGEMS_INTEGRATION_EXTRA_PATHS
                spec_dir = File.join(rubygems_integration_dir,ruby_version,"specifications")
                FileUtils.mkdir_p spec_dir unless File.exist?(spec_dir)

                gems_dir = File.join(rubygems_integration_dir,ruby_version,"gems")
                FileUtils.mkdir_p gems_dir unless File.exist?(gems_dir)

                # Link gemspec into local rubygems-integration folder
                FileUtils.ln_s gem_spec,
                    File.join(rubygems_integration_dir,ruby_version,"specifications","#{versioned_gem}.gemspec")

                # Link contents of gem into local rubygems-integration folder
                FileUtils.ln_s pkg_content, File.join(rubygems_integration_dir, ruby_version, "gems",versioned_gem)
            end
        end
        integration_paths.uniq.each do |path|
            ws.env.add_path("RUBYGEMS_INTEGRATION_EXTRA_PATHS", path)
        end
    end

    def disable_pkg(pkg_name)
        return reverse_dependencies(pkg_name)
    end

    def disable_pkg_by_pattern(pkg_name_pattern)
        all_reverse_dependencies = []
        pkg_to_deb.each do |autoproj_name, deb_name|
            if autoproj_name =~ /#{pkg_name_pattern}/
                all_reverse_dependencies << autoproj_name
                all_reverse_dependencies += reverse_dependencies(autoproj_name)
            end
        end
        return all_reverse_dependencies.uniq
    end

    def reverse_dependencies(pkg_name)
        debian_pkg_name = pkg_to_deb[pkg_name]
        if !debian_pkg_name
            return []
        end
        reverse_deps = reverse_deb_dependencies(debian_pkg_name)
        reverse_deps.map { |debian_pkg| @deb_to_pkg[debian_pkg] }.flatten.compact
    end

    def apt_update_timestamp()
        ["/var/lib/apt/periodic/update-success-stamp",
         "/var/cache/apt/pkgcache.bin"].each do |file|
            if File.exists?(file)
                return `stat -c %y #{file}`.strip()
            end
        end
    end

    def rdepends_update_timestamp()
        if File.exist?(rdepends_cache_file)
            rdepends = YAML.load_file(rdepends_cache_file)
        else
            rdepends = {}
        end

        rdepends["apt-update-timestamp"] = apt_update_timestamp()
        File.open(rdepends_cache_file, "w") do |file|
            file.write(rdepends.to_yaml)
        end
    end

    # Get reverse dependencies of the debian package
    def reverse_deb_dependencies(debian_pkg_name)
        if !debian_pkg_name
            raise ArgumentError, "reverse_dependencies requires an argument"
        end

        rdepends = {}
        if File.exists?(rdepends_cache_file)
            rdepends = YAML.load_file(rdepends_cache_file)
            timestamp = apt_update_timestamp()
            if rdepends["apt-update-timestamp"] == timestamp
                if rdepends.has_key?(debian_pkg_name)
                    return rdepends[debian_pkg_name]
                end
            else
                # File is outdate so we have to remove it
                FileUtils.rm(rdepends_cache_file)
            end
        end
        package_list = apt_cache_rdepends(debian_pkg_name)
        rdepends[debian_pkg_name] = package_list
        File.open(rdepends_cache_file, "w") do |file|
            file.write(rdepends.to_yaml)
        end
        return package_list
    end

    def apt_cache_rdepends(debian_pkg_name)
        output = `apt-cache rdepends --recurse #{debian_pkg_name}`
        package_list = []
        if !output.empty?
            rdeps_found = false
            output.split("\n").each do |line|
                if line =~ /Reverse Depends:/
                    if rdeps_found
                        break
                    else
                        rdeps_found = true
                    end
                elsif rdeps_found
                    package_list << line.strip
                end
            end
        else
            raise ArgumentError, "#{self.class}::#{__method__}: the package #{debian_pkg_name} is not known. Did you forget to call 'apt update'?"
        end
        package_list
    end

    # Write the rock-osdeps.osdeps file which allows to overload the existing
    # osdeps definition to include the debian packages
    def write_osdeps_file(filtered_osdeps, disabled_pkgs, filename: "rock-osdeps.osdeps", output_dir: File.join(__dir__,".."))
        Autoproj.message "  Triggered regeneration of rock-osdeps.osdeps: #{filename}, blacklisted packages: #{blacklist}"

        filename = File.join(output_dir, filename)
        File.write(filename, filtered_osdeps.to_yaml)

        rdepends_update_timestamp()
        Autoproj.info "rock-osdeps: the following source package usage has been enforced: #{disabled_pkgs}"
    end

    # Enumerator for all env.yml files in activated packages
    def each_package_envyml(filtered_osdeps)
        return enum_for(:each_package_envyml, filter_osdeps) unless block_given?

        filtered_osdeps.each do |pkg, data|
            debian_pkg_name = data['default']
            # Use the package name to infer the installation directory
            envyml_pattern = File.join("/opt","rock","*",debian_pkg_name,"env.yml")
            files = Dir.glob(envyml_pattern)
            files.each do |envsh_file|
                yield envsh_file unless File.empty?(envsh_file)
            end
        end
    end

    # Enumerator for all *.gemspec files in activated packages, i.e. to identify
    # packaged gems
    def each_gem_spec(filtered_osdeps)
        return enum_for(:each_gem_spec, filter_osdeps) unless block_given?

        filtered_osdeps.each do |pkg, data|
            debian_pkg_name = data['default']
            # Use the package name to infer the installation directory
            gemspec_pattern =
                File.join("/opt","rock","*",debian_pkg_name,"share","rubygems-integration","**","*.gemspec")
            files = Dir.glob(gemspec_pattern)
            files.each do |gemspec_file|
                yield gemspec_file unless File.empty?(gemspec_file)
            end
        end
    end

    # Activate and envsh, by making the values known to autoproj for internal
    # usage
    # Note, that autoproj permits to isolate the environment, so that
    # required environment variables for packages have to be set explicitely
    def activate_package_env(filter_osdeps, ws: Autoproj.workspace)
        each_package_envyml(filter_osdeps) do |envyml_file|
            yaml = YAML.load_file(envyml_file)
            delayed_handling = {}
            replace_variable = {}
            yaml.each do |varname, data|
                if data.has_key?(:priority) and data[:priority] < 0
                    delayed_handling[varname] = data
                    next
                end

                data[:values].each do |value|
                    case data[:type]
                    when :set
                        if varname =~ /APAKA__/
                            replace_variable[varname] = value
                        else
                           ws.env.set(varname, value)
                        end
                    when :add
                        ws.env.add(varname, value)
                    when :add_path
                        ws.env.add_path(varname, value)
                    when :add_prefix
                        ws.env.add_prefix(varname, value)
                    end
                end
            end

            delayed_handling.each do |varname, data|
                replace_variable.each do |v,r|
                    data[:values].each do |value|
                        value.gsub!(/\${#{v}}/,r)
                    end
                end

                data[:values].each do |value|
                    case data[:type]
                    when :set
                        ws.env.set(varname, value)
                    when :add
                        ws.env.add(varname, value)
                    when :add_path
                        ws.env.add_path(varname, value)
                    when :add_prefix
                        ws.env.add_prefix(varname, value)
                    end
                end
            end
        end
    end

    def filter_osdeps(pkg_blacklist)
        filtered_osdeps = @osdeps.dup
        if pkg_blacklist && !pkg_blacklist.empty?
            disabled_pkgs = pkg_blacklist
            pkg_blacklist.each do |pkg_name|
                if pkg_name =~ /\A[^+*{}(),;$]+\z/
                    disabled_pkgs += disable_pkg(pkg_name)
                else
                    disabled_pkgs += disable_pkg_by_pattern(pkg_name)
                    # remove pattern from list
                    disabled_pkgs.delete(pkg_name)
                end
            end
            Autoproj.message "  Disabling osdeps: #{disabled_pkgs.sort}"
            disabled_pkgs.flatten.each do |pkg|
                filtered_osdeps.delete(pkg)
            end
        end
        [filtered_osdeps, disabled_pkgs]
    end

    # Check on the availability of a file named 'deb_blacklist.yml'
    # in the autoproj/ folder
    # in should contain the list of packages that should not be used as debian
    # package, e.g.:
    #
    # ---
    #  - base/types
    #
    # This allows to infer all reverse dependencies that base/types has and
    # so that they are also accounted for in the blacklisting process
    # return filtered osdeps, disabled pkgs
    def load_blacklist(ws: Autoproj.workspace)
        blacklist_file = File.join(ws.config_dir, "deb_blacklist.yml")
        if File.exists?(blacklist_file)
            @blacklist = YAML.load_file(blacklist_file)
        end

        filter_osdeps(@blacklist)
    end

    # Validate the mapping from alias to debian packages in the existin osdeps
    # file
    # @param package_name [String] Optionally limit the validation to a single
    #   package
    # @return [Array<String>] Return array of packages that failed validation
    def validate(package_name = nil)
        missing = {}
        packages = {}
        if package_name
            if @pkg_to_deb.has_key?(package_name)
                packages[package_name] = @pkg_to_deb[package_name]
            else
                raise ArgumentError, "#{self} package '#{package_name}'"\
                    " is not defined"
            end
        else
            packages = @pkg_to_deb
        end
        packages.each do |k,v|
            if PackageSelector.available?(v)
                Autoproj.message "#{k} : #{v} [OK]"
            else
                Autoproj.warn "#{k} : #{v} [MISSING]"
                missing[k] = v
            end
        end

        if missing.empty?
            Autoproj.message "Perfect - all packages point to a known Debian package in your osdeps file."
        else
            Autoproj.warn "Packages #{missing.keys.join(",")} are listed to have a debian package,"\
                "but their debian packages are unknown to 'apt'.\nDid you forget "\
                "to call 'apt update'?"
        end
        return missing.keys
    end

    # Check with 'apt show' if a package with the given name is already installed
    # @param package_name [String] name of the package
    # @return [Bool] true if package is already installed, false otherwise
    def self.available?(package_name)
        msg, status = Open3.capture2e("apt show #{package_name}")
        Autoproj.debug msg
        return status.success?
    end
end

end # DebianPackaging
end # Rock
