# Setup of the TYPELIB_PLUGIN_PATH
typelib_plugin_path = nil
if defined?(Autobuild.environment)
    typelib_plugin_path = Autobuild.environment['TYPELIB_PLUGIN_PATH']
else
    typelib_plugin_path = Autobuild.env.environment['TYPELIB_PLUGIN_PATH']
end

release_dir="/opt/rock/#{Autoproj.user_config('debian_release')}"
Autoproj.env_set 'TYPELIB_PLUGIN_PATH', File.join(release_dir, 'lib','typelib')
if typelib_plugin_path && !typelib_plugin_path.empty?
    typelib_plugin_path = typelib_plugin_path.first
    if !File.exists?(typelib_plugin_path)
        FileUtils.mkdir_p typelib_plugin_path
    end
    Autoproj.env_add 'TYPELIB_PLUGIN_PATH', typelib_plugin_path
end

architecture = "#{`gcc -print-multiarch`}".strip
deb_cxx_flags = []
deb_cxx_flags << "-I#{Autoproj.root_dir}/install/include"
deb_cxx_flags << "-L#{Autoproj.root_dir}/install/lib/#{architecture}"
deb_cxx_flags << "-L#{Autoproj.root_dir}/install/lib"

Autobuild::Package.each do |name, pkg|
    if pkg.respond_to?(:define)
        existing_cxx_flags=pkg.defines['CMAKE_CXX_FLAGS']
        if existing_cxx_flags
            existing_cxx_flags = existing_cxx_flags.split(" ")
        else
            existing_cxx_flags = []
        end
        extra_cxx_flags  = Array.new

        deb_cxx_flags.each do |flag|
            if existing_cxx_flags.include?(flag)
                existing_cxx_flags.delete(flag)
            end
        end
        cxx_flags = deb_cxx_flags + existing_cxx_flags

        cxx_flags = cxx_flags.join(" ")
        if !cxx_flags.empty?
            pkg.define "CMAKE_CXX_FLAGS", cxx_flags
        end
    end
end
