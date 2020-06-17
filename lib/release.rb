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
    # Whether the debian packages come with a separate
    # package prefix
    attr_reader :separate_prefixes

    DEFAULT_DATA_DIR = File.join(__dir__,"..","data")
    DEFAULT_SPEC_FILE = "releases.yml"

    @@multi_arch = "#{`gcc -print-multiarch`}".strip
    @@debian_arch = "#{`dpkg --print-architecture`}".strip

    # Retrieve the available list of releases
    # @param data_dir [String] directory that contain the information about the
    #  release and osdeps files
    # @param [Array<String>] list of release names
    def self.available(data_dir: nil,
                                spec_file: nil)
        data_dir ||= DEFAULT_DATA_DIR
        spec_file ||= DEFAULT_SPEC_FILE

        releases_spec_file = File.join(data_dir, spec_file)
        spec = YAML::load_file(releases_spec_file)
        return spec.keys.select { |x| x !~ /default/ }
    end

    def by_name(name)
        if !@releases.has_key?(name)
            @releases[name] = Release.new(name,
                                                 data_dir: data_dir,
                                                 spec_data: spec,
                                                 arch: arch,
                                                 ws: ws
                                                )
        end
        @releases[name]
    end

    # Retrieve the current release hierarchy from a given release name
    # and a hierarchy spec, which should look like
    #
    # ---
    # default:
    #     repo_url: http://rock.hb.dfki.de/rock-releases
    #     public_key: http://rock.hb.dfki.de/rock-release/rock-robotics.public.key
    #     separate_prefixes: true
    # master-18.01:
    #     separate_prefixes: false
    # master-19.06:
    #     depends_on: ["master-18.06"]
    #     repo_url: http://myserver.org/release
    #     public_key: http://mykeyserver.org/public_key
    #     separate_prefixes: false
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
        @releases = {}
        @data_dir = data_dir || DEFAULT_DATA_DIR
        if spec_file && spec_data
            raise ArgumentError, "#{self.class} please provide either spec_data"\
                " or spec_file"
        end
        if !spec_file && !spec_data
            spec_file = DEFAULT_SPEC_FILE
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
            @separate_prefixes = @spec['default']['separate_prefixes']
        end

        if !@spec.has_key?(release_name)
            raise ArgumentError, "Release file #{@spec} does not contain: #{release_name} -- please inform the maintainer of the package_set rock-osdeps"
        end
        @name = release_name
        @ws = ws
        @arch = arch || @@debian_arch

        @hierarchy = dependencies(@name).reverse

        data = @spec[release_name]
        return unless data
        @repo_url = data['repo_url'] if data.has_key?('repo_url')
        @public_key = data['public_key'] if data.has_key?('public_key')
        @separate_prefixes = data['separate_prefixes'] if data.has_key?('separate_prefixes')
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
    def self.multi_arch
        @@multi_arch
    end

    def self.debian_arch
        @@debian_arch
    end

    def self.architecture()
        Release.debian_arch
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

    def enable_shell_extension(extension_dir)
        shell_extension = nil
        if ENV.has_key?('SHELL')
            ["zsh","bash","sh"].each do |shell|
                if ENV['SHELL'].include?("/#{shell}")
                    shell_extension = File.join(extension_dir, shell)
                    break
                end
            end
        else
            Autoproj.warn "Failed to identify active shell type, "
                "cannot select a shell extension"
        end

        if shell_extension and File.exist?(shell_extension)
            Autobuild.env_source_file(shell_extension)
        end
    end

    # Update the environmental setting
    def update_env
        # identify the major.minor version of python
        python_version=
        if Autoproj.config.has_value_for?('python_version')
            python_version = Autoproj.config.get('python_version')
        else
            require 'open3'
            msg, status = Open3.capture2e("which python")
            if status.success?
                python_version=`python -c "import sys; version=sys.version_info[:3]; print('{0}.{1}'.format(*version))"`.strip
            end
        end

        Autoproj.info "Updating env for required releases: #{hierarchy}"
        hierarchy.each do |release_name|
            release_install_dir = "/opt/rock/#{release_name}"

            sub_release = by_name(release_name)
            if sub_release.separate_prefixes
                # Activate available shell extensions (and account for pkg
                # prefix in path)
                Dir.glob(File.join(release_install_dir,"*","share","scripts","shell")).each do |dir|
                    enable_shell_extension(dir)
                end

                next
            else
                enable_shell_extension(File.join(release_install_dir, "share","scripts","shell"))
            end

            rock_ruby_archdir       = RbConfig::CONFIG['archdir'].gsub("/usr", release_install_dir)
            rock_ruby_vendordir     = File.join(release_install_dir,"/lib/ruby/vendor_ruby")
            rock_ruby_vendorarchdir = RbConfig::CONFIG['vendorarchdir'].gsub("/usr", release_install_dir)
            rock_ruby_sitedir       = RbConfig::CONFIG['sitedir'].gsub("/usr", release_install_dir)
            rock_ruby_sitearchdir   = RbConfig::CONFIG['sitearchdir'].gsub("/usr", release_install_dir)
            rock_ruby_libdir        = RbConfig::CONFIG['rubylibdir'].gsub("/usr", release_install_dir)

            Autobuild.env.add('PATH',File.join(release_install_dir,"bin"))
            Autobuild.env.add('CMAKE_PREFIX_PATH',File.join(release_install_dir))
            Autobuild.env.add('CMAKE_PREFIX_PATH',File.join(release_install_dir,"share/rock/cmake"))
            Autobuild.env.add('CMAKE_PREFIX_PATH',File.join(Autoproj.root_dir,"install"))
            Autobuild.env.add('CMAKE_PREFIX_PATH',File.join(Autoproj.root_dir,"install/share/rock/cmake"))
            Autobuild.env.add('PKG_CONFIG_PATH',File.join(release_install_dir,"lib",Release.multi_arch, "pkgconfig"))
            Autobuild.env.add('PKG_CONFIG_PATH',File.join(release_install_dir,"lib","pkgconfig"))

            # RUBY SETUP
            Autobuild.env.add('RUBYLIB',rock_ruby_archdir)
            Autobuild.env.add('RUBYLIB',rock_ruby_vendordir)
            Autobuild.env.add('RUBYLIB',rock_ruby_vendorarchdir)
            Autobuild.env.add('RUBYLIB',rock_ruby_sitedir)
            Autobuild.env.add('RUBYLIB',rock_ruby_sitearchdir)
            Autobuild.env.add('RUBYLIB',rock_ruby_libdir)

            # Needed for qt
            Autobuild.env.add('RUBYLIB',File.join(rock_ruby_archdir.gsub(RbConfig::CONFIG['RUBY_PROGRAM_VERSION'],'')) )
            Autobuild.env.add('RUBYLIB',File.join(release_install_dir,"/lib/ruby/vendor_ruby/standard"))
            Autobuild.env.add('RUBYLIB',File.join(release_install_dir,"/lib/ruby/vendor_ruby/core"))

            Autobuild.env.add('RUBYLIB',File.join(release_install_dir,"lib",Release.multi_arch, "ruby"))
            Autobuild.env.add('RUBYLIB',File.join(release_install_dir,"/lib/ruby"))

            # PYTHON SETUP
            if python_version
                Autobuild.env.add('PYTHONPATH', File.join(release_install_dir,"lib","python#{python_version}","site-packages"))
            end

            # Runtime setup
            Autobuild.env.add('LD_LIBRARY_PATH',File.join(release_install_dir,"lib",Release.multi_arch))
            Autobuild.env.add('LD_LIBRARY_PATH',File.join(release_install_dir,"lib"))
            Autobuild.env.add('LD_LIBRARY_PATH',File.join(ws.root_dir,"install","lib",Release.multi_arch))
            Autobuild.env.add('LD_LIBRARY_PATH',File.join(ws.root_dir,"install","lib"))

            # Compile time setup -- prefer locally installed packages over debian packages
            Autobuild.env.add('LIBRARY_PATH',File.join(release_install_dir,"lib",Release.multi_arch))
            Autobuild.env.add('LIBRARY_PATH',File.join(release_install_dir,"lib"))
            Autobuild.env.add('LIBRARY_PATH',File.join(ws.root_dir,"install","lib",Release.multi_arch))
            Autobuild.env.add('LIBRARY_PATH',File.join(ws.root_dir,"install","lib"))

            Autobuild.env.add('OROGEN_PLUGIN_PATH', File.join(release_install_dir,"/share/orogen/plugins"))
            Autobuild.env.add('TYPELIB_RUBY_PLUGIN_PATH', File.join(release_install_dir,"/share/typelib/ruby"))
            # gui/vizkit3d specific settings
            Autobuild.env.add('QT_PLUGIN_PATH', File.join(release_install_dir, "/lib/qt"))
            Autobuild.env.add('VIZKIT_PLUGIN_RUBY_PATH', File.join(release_install_dir, "/lib/vizkit"))
            Autobuild.env.add('VIZKIT_PLUGIN_RUBY_PATH', File.join(release_install_dir, "/lib"))
            Autobuild.env.add('OSG_FILE_PATH', File.join(release_install_dir, "/share/vizkit"))
            # Roby plugins: base/scripts, syskit
            ["rock/roby_plugin.rb", "syskit/roby_app/register_plugin.rb"].each do |roby_plugins|
                Autobuild.env.add('ROBY_PLUGIN_PATH', File.join(rock_ruby_vendordir, roby_plugins))
            end
            Autobuild.env.add('ROCK_BUNDLE_PATH', File.join(release_install_dir, "share/rock/bundles"))
        end

        Autobuild.env_remove_path('PATH',File.join(ws.root_dir,"install","bin"))
        Autobuild.env.add('PATH',File.join(ws.root_dir,"install","bin"))

        Autobuild.env.add('PKG_CONFIG_PATH',File.join("/usr/share/","pkgconfig"))
        Autobuild.env.add('PKG_CONFIG_PATH',File.join("/usr/lib/","pkgconfig"))
        Autobuild.env.add('PKG_CONFIG_PATH',File.join("/usr/lib/",Release.multi_arch,"pkgconfig"))
        Autobuild.env.add('PKG_CONFIG_PATH',File.join(ws.root_dir,"install","lib","pkgconfig"))

        Autoproj.env_set('ROCK_DEB_RELEASE_NAME',name)
        env_hierarchy = ""
        hierarchy.each do |release_name|
            sub_release = by_name(release_name)
            env_hierarchy += "#{name}:#{sub_release.repo_url}/#{sub_release.name};"
        end
        Autoproj.env_set('ROCK_DEB_RELEASE_HIERARCHY',env_hierarchy)
    end

    def update_apt_list
        current_release_name = name

        apt_update_required = false
        hierarchy.each do |release_name|
            Autoproj.info "Activating release: #{release_name}"
            sub_release = by_name(release_name)

            apt_rock_list_file = "/etc/apt/sources.list.d/rock-#{release_name}.list"
            apt_source = "[arch=#{Release.debian_arch} trusted=yes] #{sub_release.repo_url}/#{sub_release.name} #{current_release_name} main"
            update = false
            if !File.exist?(apt_rock_list_file)
                update = true
            else
                File.open(apt_rock_list_file,"r") do |f|
                    apt_source_existing = f.gets
                    regexp = Regexp.new( Regexp.escape(apt_source) )
                    if !regexp.match(apt_source_existing)
                        Autoproj.message "  Existing apt source needs update: #{apt_source_existing}"
                        Autoproj.message "  Changing to: #{apt_source}"
                        update = true
                        Autoproj.warn "  You switched to using a new debian release, so please trigger a rebuild after completing this configuration"
                    end
                end
            end

            if update
                if !system("echo deb #{apt_source} | sudo tee #{apt_rock_list_file}")
                    Autoproj.warn "Failed to install apt source: #{apt_source}"
                else
                    Autoproj.message "Adding deb-src entry"
                    system("echo deb-src #{apt_source} | sudo tee -a #{apt_rock_list_file}")

                    if sub_release.public_key
                        Autoproj.message "Adding public key for rock-robotics"
                        if !system("wget -qO - #{sub_release.public_key} | sudo apt-key add -")
                            Autoproj.warn "Failed to add public key for rock-robotics"
                        end
                    end
                    apt_update_required ||= true
                end
            end
        end
        if apt_update_required
            Autoproj.message "  Updating package source -- this can take some time"
            system("sudo apt-get update > /tmp/autoproj-update.log")
        end
    end
end # end Release

end # end DebianPackaging
end # end Rock
