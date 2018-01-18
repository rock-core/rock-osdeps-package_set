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
        @osdeps.each do | pkg_name, osdeps_list|
            osdeps_list[distribution.join(",")].each do |key, debian_pkg_name|
                supported_releases = key.split(",")
                if supported_releases.include?(release.first)
                    @pkg_to_deb[pkg_name] = debian_pkg_name
                    @deb_to_pkg[debian_pkg_name] = [pkg_name]
                end
            end
        end
    end

    def self.activate_releases(release_names)
        distribution, release = operating_system
        architecture = "#{`dpkg --print-architecture`}".strip
        ps = Rock::DebianPackaging::PackageSelector.new
        release_names.each do |release_name|
            ps.load_osdeps_file( File.join(File.dirname(__FILE__),"..","data","#{release_name}-#{architecture}.yml") )
        end
        ps.load_blacklist
        ps.write_osdeps_file
    end

    # Activate the package list for a particular debian package release
    def self.activate_release(release_name)
        distribution, release = operating_system
        architecture = "#{`dpkg --print-architecture`}".strip
        ps = Rock::DebianPackaging::PackageSelector.new(File.join(File.dirname(__FILE__),"..","data","#{release_name}-#{architecture}.yml"))
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
            raise "Unsupported Autoproj API: please inform the developer"
        end
    end

    def disable_pkg(pkg_name)
        reverse_dependencies(pkg_name)
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
        output = `apt-cache rdepends #{debian_pkg_name}`
        if !output.empty?
            package_list = output.split(":")[1]
            if package_list
                return package_list.split(' ')
            end
        else
            raise ArgumentError, "The package #{debian_pkg_name} is not known. Did you forget to call 'apt update'?"
        end
        []
    end

    # Write the rock-osdeps.osdeps file which allows to overload the existing
    # osdeps definition to include the debian packages
    def write_osdeps_file(filename = nil)
        if !filename
            filename = File.join(File.dirname(__FILE__),"..","rock-osdeps.osdeps")
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
                disabled_pkgs += disable_pkg(pkg_name)
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
