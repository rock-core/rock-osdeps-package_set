require 'yaml'

module Rock
module DebianPackaging

class ReleaseHierarchy

    # Retrieve the current release hierarchy from a given release name
    # and a hierarchy spec, which should look like
    #
    #    ---
    #    master-18.01:
    #    drock-18.01:
    #        - master-18.01
    #
    def self.current(main_release, hierarchy_spec)
        release_hierarchy = [ main_release ]
        if File.exists?(hierarchy_spec)
            spec = YAML::load_file(hierarchy_spec)
            if spec.has_key?(main_release)
                if spec[main_release]
                    release_hierarchy << spec[main_release]
                end
            else
                Autoproj.warn "Release file #{hierarchy_spec} does not contain: #{main_release} -- please inform the maintainer of the package_set rock-osdeps"
            end
        end
        release_hierarchy = release_hierarchy.flatten.reverse
    end
end # end ReleaseHierarchy

end
end
