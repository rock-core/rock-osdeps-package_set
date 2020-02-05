require 'yaml'

module Rock
module DebianPackaging

class Release
    attr_reader :name
    attr_reader :hierarchy
    attr_reader :repo_url
    attr_reader :public_key

    attr_reader :spec

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
        @spec = YAML::load_file(releases_spec)

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

    def dependencies(release_name)
        hierarchy = [release_name]
        data = @spec[release_name]
        if data && data.has_key?('depends_on')
            dependant_release = data['depends_on']
            hierarchy += dependencies(dependant_release)
        end
        return hierarchy
    end

    def retrieve_osdeps_file(architecture, target_dir)
        filename = "#{@name}-#{architecture}.yml"

        url = repo_url
        url += "/" unless url =~ /\/$/
        url += "#{@name}/osdeps/#{filename}"

        FileUtils.mkdir_p target_dir unless File.exists?(target_dir)
        Dir.chdir(target_dir) do
            if !File.exists?(filename)
                cmd = "wget #{url}"
                msg, status = Open3.capture2e(cmd)
                if status.success? && status.exitstatus == 0
                    if !File.exists?(filename)
                        raise ArgumentError, "Release #{@name} has no package "\
                            "definition available for #{architecture} -- #{filename} missing"
                    end
                end
            end
        end
    end
end # end Release

end # end DebianPackaging
end # end Rock
