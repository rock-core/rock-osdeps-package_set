require 'yaml'
require 'autoproj'
require_relative 'release'

module Rock
module DebianPackaging

class PackageSelector
    attr_reader :osdeps
    attr_reader :pkg_to_deb
    attr_reader :deb_to_pkg
    attr_reader :blacklist

    attr_reader :rdepends_cache_file

    def initialize(osdeps_file = nil)
        @osdeps = {}
        if osdeps_file
            load_osdeps_file(osdeps_file)
        end
        @rdepends_cache_file = File.join(__dir__,"..",".rdepends-cache.yml")
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

        distribution, release = PackageSelector::operating_system

        compact_osdeps = {}
        osdeps.each do |pkg_name, osdeps_list|
            pkgs = nil
            if osdeps_list.has_key?(distribution.first)
                pkgs = osdeps_list[distribution.first]
            elsif osdeps_list.has_key?(distribution.join(","))
                pkgs = osdeps_list[distribution.join(",")]
            end
            if !pkgs || pkgs.empty?
                raise ArgumentError, "#{self.class}::#{__method__}: #{osdeps_file} does not contain information" \
                    " for package '#{pkg_name}' and distribution '#{distribution.join(",")}'"
            end
            pkgs.each do |key, debian_pkg_name|
                supported_releases = key.split(",")
                if supported_releases.include?(release.first)
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
                              output_dir: File.join(__dir__,"..")
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
                               output_dir: File.join(__dir__,".."),
                               auto_update: true
                            )
        ps = Rock::DebianPackaging::PackageSelector.new
        package_list_updated = false
        release_names.each do |release_name|
            release = Rock::DebianPackaging::Release.new(release_name,
                                                         data_dir: data_dir,
                                                         spec_file: spec_file,
                                                         spec_data: spec_data,
                                                         ws: ws)
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
        ps.load_blacklist(ws: ws)
        ps.write_osdeps_file(output_dir: output_dir)
        ps
    end

    # Retrieve the operating system
    def self.operating_system
        if defined?(Autoproj::OSDependencies)
            Autoproj::OSDependencies.operating_system
        elsif defined?(Autoproj::OSPackageResolver)
            Autoproj::OSPackageResolver.autodetect_operating_system
        else
            raise "#{self.class}::#{__method__}: unsupported Autoproj API: please inform the developer"
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
    def write_osdeps_file(filename: "rock-osdeps.osdeps", output_dir: File.join(__dir__,".."))
        filename = File.join(output_dir, filename)
        Autoproj.message "  Triggered regeneration of rock-osdeps.osdeps: #{filename}, blacklisted packages: #{blacklist}"
        write_file(filename, blacklist)
    end

    # Write the osdeps file excluding the blacklisted packages
    def write_file(outfile, pkg_blacklist)
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
        rdepends_update_timestamp()
        File.write(outfile, filtered_osdeps.to_yaml)
        Autoproj.info "rock-osdeps: the following source package usage has been enforced: #{disabled_pkgs}"
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
    def load_blacklist(ws: Autoproj.workspace)
        blacklist_file = File.join(ws.config_dir, "deb_blacklist.yml")
        if File.exists?(blacklist_file)
            @blacklist = YAML.load_file(blacklist_file)
        end
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
