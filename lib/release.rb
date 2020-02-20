require 'yaml'
require 'readline'

module Rock
module DebianPackaging

class Release
    attr_reader :name
    attr_reader :hierarchy
    attr_reader :repo_url
    attr_reader :public_key

    attr_reader :ws
    attr_reader :arch
    attr_reader :data_dir
    attr_reader :spec

    DEFAULT_DATA_DIR = File.join(__dir__,"..","data")
    @@arch = "#{`dpkg --print-architecture`}".strip

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
    # @param release_name [String] name of the release
    # @param data_dir [String] path to the directory of the release's osdeps
    #     files
    # @param arch [String] architecture label (amd64,arm64,armel,armel, ...)
    # @param ws [Autoproj::Workspace] workspace of the current autoproj instance
    def initialize(release_name,
                   data_dir: nil,
                   spec_file: nil,
                   spec_data: nil,
                   arch: nil,
                   ws: Autoproj.workspace)
        @data_dir = data_dir || DEFAULT_DATA_DIR
        if spec_file && spec_data
            raise ArgumentError, "#{self.class} please provide either spec_data"\
                " or spec_file"
        end
        if !spec_file && !spec_data
            spec_file = "releases.yml"
        end

        if spec_file
            releases_spec_file = File.join(@data_dir, spec_file)
            @spec = YAML::load_file(releases_spec_file)
        elsif spec_data
            raise ArgumentError, "#{self.class} spec data has wrong format - expected hash"\
                " got #{spec_data.class}" unless spec_data.kind_of?(Hash)
            @spec = spec_data
        end

        if !@spec
            raise RuntimeError, "#{self.class} invalid spec provided - expected filename (String) or data (Hash)"\
                " spec_file: #{spec_file} -- spec_data: #{spec_data}"
        end


        if @spec.has_key?('default')
            @repo_url = @spec['default']['repo_url']
            @public_key = @spec['default']['public_key']
        end

        if !@spec.has_key?(release_name)
            raise ArgumentError, "Release file #{@spec} does not contain: #{release_name} -- please inform the maintainer of the package_set rock-osdeps"
        end
        @name = release_name
        @ws = ws
        @arch = arch || @@arch

        @hierarchy = dependencies(@name).reverse

        data = @spec[release_name]
        return unless data
        @repo_url = data['repo_url'] if data.has_key?('repo_url')
        @public_key = data['public_key'] if data.has_key?('public_key')
    end

    def to_s
        "Release #{@name}/#{@arch} (which depends on: #{@hierarchy})"
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
        @@arch
    end

    def osdeps_filename(suffix: nil)
        return "#{@name}-#{@arch}.yml#{suffix}"
    end

    def retrieve_osdeps_file(suffix: nil,
                             force: false)
        remote_filename = osdeps_filename()
        local_filename = osdeps_filename(suffix: suffix)

        url = repo_url
        url += "/" unless url =~ /\/$/
        url += "#{@name}/osdeps/#{remote_filename}"

        FileUtils.mkdir_p @data_dir unless File.exists?(@data_dir)
        Dir.chdir(@data_dir) do
            if force
                FileUtils.rm local_filename if File.exists?(local_filename)
            end

            if !File.exists?(local_filename)
                wget = `which wget`
                if wget.empty?
                    raise RuntimeError,
                        "Could not find 'wget' - cannot retrieve release files"
                end
                cmd = "wget #{url} -O #{local_filename}"
                msg, status = Open3.capture2e(cmd)
                if !status.success?
                    FileUtils.rm local_filename
                    raise ArgumentError, "Release #{@name} has no package "\
                        "definition available for #{@arch} -- "\
                        " #{remote_filename} missing -- #{msg}"
                end
            end
        end
        File.join(@data_dir, local_filename)
    end

    def update()
        suffix = ".remote"
        begin
            Dir.glob("*#{suffix}").each { |file| File.delete(file) }
            retrieve_osdeps_file(suffix: suffix, force: true)
        rescue ArgumentError => e
            Autoproj.debug "#{e}"
        end

        remote_filename = osdeps_filename(suffix: suffix)
        local_filename = osdeps_filename()
        Dir.chdir(@data_dir) do
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
