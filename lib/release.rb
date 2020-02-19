require 'yaml'
require 'readline'

module Rock
module DebianPackaging

class Release
    attr_reader :name
    attr_reader :hierarchy
    attr_reader :repo_url
    attr_reader :public_key

    attr_reader :spec

    @@architecture = "#{`dpkg --print-architecture`}".strip

    # Retrieve the current release hierarchy from a given release name
    # and a hierarchy spec, which should look like
    #
    # ---
    # default:
    #     repo_url: http://rock.hb.dfki.de/rock-releases
    #     public_key: http://rock.hb.dfki.de/rock-release/rock-robotics.public.key
    # master-18.01:
    # master-19.06:
    #     depends_on: ["master-18.06"]
    #     repo_url: http://myserver.org/release
    #     public_key: http://mykeyserver.org/public_key
    #
    def initialize(release_name, releases_spec)
        @spec = nil
        if releases_spec.kind_of?(String)
            @spec = YAML::load_file(releases_spec)
        elsif releases_spec.kind_of?(Hash)
            @spec = releases_spec
        end

        raise RuntimeError, "#{self.class} invalid spec provided - expected filename (String) or data (Hash)" unless @spec

        if @spec.has_key?('default')
            @repo_url = @spec['default']['repo_url']
            @public_key = @spec['default']['public_key']
        end

        if !@spec.has_key?(release_name)
            raise ArgumentError, "Release file #{@spec} does not contain: #{release_name} -- please inform the maintainer of the package_set rock-osdeps"
        end
        @name = release_name

        @hierarchy = dependencies(@name).reverse

        data = @spec[release_name]
        return unless data
        @repo_url = data['repo_url'] if data.has_key?('repo_url')
        @public_key = data['public_key'] if data.has_key?('public_key')
    end

    def to_s
        "Release #{@name}/#{@@architecture} (which depends on: #{@hierarchy})"
    end

    def dependencies(release_name)
        hierarchy = [release_name]
        data = @spec[release_name]
        if data && data.has_key?('depends_on')
            dependant_release = data['depends_on']
            hierarchy += dependencies(dependant_release)
        end
        return hierarchy
    end

    # Get the current system architecture
    def self.architecture()
        @@architecture
    end

    def osdeps_filename(architecture, target_dir, suffix = nil)
        return "#{@name}-#{architecture}.yml#{suffix}"
    end

    def retrieve_osdeps_file(architecture, target_dir, suffix = nil)
        remote_filename = osdeps_filename(architecture, target_dir)
        local_filename = osdeps_filename(architecture, target_dir, suffix)

        url = repo_url
        url += "/" unless url =~ /\/$/
        url += "#{@name}/osdeps/#{remote_filename}"

        FileUtils.mkdir_p target_dir unless File.exists?(target_dir)
        Dir.chdir(target_dir) do
            if !File.exists?(local_filename)
                wget = `which wget`
                if wget.empty?
                    raise RuntimeError,
                        "Could not find 'wget' - cannot retrieve release files"
                end
                cmd = "wget #{url} -O #{local_filename}"
                msg, status = Open3.capture2e(cmd)
                if status.success? && status.exitstatus == 0
                    if !File.exists?(local_filename)
                        raise ArgumentError, "Release #{@name} has no package "\
                            "definition available for #{architecture} -- #{remote_filename} missing"
                    end
                end
            end
        end
        File.join(target_dir, local_filename)
    end

    def update(target_dir, arch: nil, ws: Autoproj.workspace)
        if !arch
            arch = @@architecture
        end

        suffix = ".remote"
        begin
            Dir.glob("*#{suffix}").each { |file| File.delete(file) }
            retrieve_osdeps_file(arch, target_dir, suffix)
        rescue ArgumentError => e
            Autoproj.debug "#{e}"
        end

        remote_filename = osdeps_filename(arch, target_dir, suffix)
        local_filename = osdeps_filename(arch, target_dir)
        Dir.chdir(target_dir) do
            if File.exists?(remote_filename)
                if File.exists?(local_filename)
                    # Display different and update
                    if !FileUtils.identical?(remote_filename, local_filename)
                        if ws.config.interactive?
                            answer =  Readline.readline "Package definitions for the release #{name}/#{arch} have changed. Show diff [Y/n]"
                            if answer =~ /Y/i
                                msg, status = Open3.capture2e("diff #{remote_filename} #{local_filename}")
                                Autoproj.message msg
                            end
                        end
                        FileUtils.mv remote_filename, local_filename
                        return true
                    else
                        return false
                    end
                else
                    Autoproj.info "Retrieved package definitions: #{local_filename}"
                    FileUtils.mv remote_filename, local_filename
                    return true
                end
            end
        end
    end
end # end Release

end # end DebianPackaging
end # end Rock
