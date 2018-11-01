require 'yaml'
require 'autoproj'

module Rock
module DebianPackaging

class PackageSelector
    attr_reader :osdeps
    attr_reader :pkg_to_deb
    attr_reader :deb_to_pkg
    attr_reader :blacklist

    def initialize(osdeps_file = nil)
        if osdeps_file
            load_osdeps_file(osdeps_file)
        end
    end

    def load_osdeps_file(osdeps_file)
        if !@osdeps
            @osdeps = YAML.load_file(osdeps_file)
        else
            osdeps = YAML.load_file(osdeps_file)
            @osdeps.merge!(osdeps)
        end

        @pkg_to_deb ||= {}
        @deb_to_pkg ||= {}
        @reverse_dependencies_map ||= {}

        distribution, release = PackageSelector::operating_system
        @osdeps.each do |pkg_name, osdeps_list|
            pkgs = osdeps_list[distribution.join(",")]
            if !pkgs || pkgs.empty?
                raise ArgumentError, "#{self.class}::#{__method__}: #{osdeps_file} does not contain information" \
                    " for package '#{pkg_name}' and distribution '#{distribution.join(",")}'"
            end
            pkgs.each do |key, debian_pkg_name|
                supported_releases = key.split(",")
                if supported_releases.include?(release.first)
                    @pkg_to_deb[pkg_name] = debian_pkg_name
                    @deb_to_pkg[debian_pkg_name] = [pkg_name]
                end
            end
        end
    end

    # Retrieve the osdeps file for this release and the current architecture
    def self.release_osdeps_file(release_name)
        architecture = "#{`dpkg --print-architecture`}".strip
        release_file = File.join(__dir__,"..","data","#{release_name}-#{architecture}.yml")
        if !File.exist?(release_file)
            raise ArgumentError, "#{self.class}::#{__method__}: rock release '#{release_name}' has no osdeps file for the architecture '#{architecture}' -- #{File.absolute_path(release_file)} missing"
        end
        release_file
    end

    # Retrieve the available list of releases
    def self.available_releases
        architecture = "#{`dpkg --print-architecture`}".strip
        glob_filename = File.join(__dir__,"..","data","*-#{architecture}.yml")
        releases = []
        Dir.glob(glob_filename).each do |filename|
            releases << File.basename( filename ).gsub(/-#{architecture}.yml$/,'')
        end
        releases
    end

    def self.activate_releases(release_names)
        ps = Rock::DebianPackaging::PackageSelector.new
        release_names.each do |release_name|
            ps.load_osdeps_file release_osdeps_file(release_name)
        end
        ps.load_blacklist
        ps.write_osdeps_file
    end

    # Activate the package list for a particular debian package release
    def self.activate_release(release_name)
        ps = Rock::DebianPackaging::PackageSelector.new release_osdeps_file(release_name)
        ps.load_blacklist
        ps.write_osdeps_file
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

    # Get reverse dependencies of the debian package
    def reverse_deb_dependencies(debian_pkg_name)
        if !debian_pkg_name
            raise ArgumentError, "reverse_dependencies requires an argument"
        end
        output = `apt-cache rdepends --recurse #{debian_pkg_name}`
        package_list = []
        if !output.empty?
            rdeps_found = false
            output.split("\n").each do |line|
                if line =~ /Reverse Depends:/
                    rdeps_found = true
                elsif rdeps_found
                    rdeps_found = false
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
    def write_osdeps_file(filename = nil)
        if !filename
            filename = File.join(__dir__,"..","rock-osdeps.osdeps")
        end
        puts "  Triggered regeneration of rock-osdeps.osdeps: #{filename}, blacklisted packages: #{blacklist}"
        write_file(filename, blacklist)
    end

    # Write the the osdeps file excluding the blacklisted packages
    def write_file(outfile, pkg_blacklist)
        filtered_osdeps = @osdeps.dup
        if pkg_blacklist && !pkg_blacklist.empty?
            disabled_pkgs = pkg_blacklist
            pkg_blacklist.each do |pkg_name|
                if pkg_name[-1] == "*"
                    disabled_pkgs += disable_pkg_by_pattern(pkg_name)
                    # remove pattern from list
                    disabled_pkgs.delete(pkg_name)
                else
                    disabled_pkgs += disable_pkg(pkg_name)
                end
            end
            puts "  Disabling osdeps: #{disabled_pkgs}"
            disabled_pkgs.flatten.each do |pkg|
                filtered_osdeps.delete(pkg)
            end
        end

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
    def load_blacklist
        config_dir = nil
        if Autoproj.respond_to?(:workspace)
            config_dir = Autoproj.workspace.config_dir
        else
            config_dir = Autoproj.config_dir
        end

        blacklist_file = File.join(config_dir, "deb_blacklist.yml")
        if File.exists?(blacklist_file)
            @blacklist = YAML.load_file(blacklist_file)
        end
    end
end

end # DebianPackaging
end # Rock
