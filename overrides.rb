if Autoproj.user_config('DEB_USE')
    # Setup of the TYPELIB_PLUGIN_PATH
    typelib_plugin_path = nil
    if defined?(Autobuild.environment)
        typelib_plugin_path = Autobuild.environment['TYPELIB_PLUGIN_PATH']
    else
        typelib_plugin_path = Autobuild.env.environment['TYPELIB_PLUGIN_PATH']
    end

    # Make sure the release path to typelib is used, when there is no local
    # installation
    if Dir.glob(File.join(typelib_plugin_path, "**")).empty?
        release_dir="/opt/rock/#{Autoproj.user_config('debian_release')}"
        Autoproj.env_set 'TYPELIB_PLUGIN_PATH', File.join(release_dir, 'lib','typelib')
    end
end
