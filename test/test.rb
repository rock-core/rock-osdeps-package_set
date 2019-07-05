require 'autoproj'
require 'minitest/autorun'

require_relative '../lib/package_selector'

module Rock
    describe "reverse_dependency" do
        it "collects all reverse dependencies" do
            @ps = Rock::DebianPackaging::PackageSelector.new
            deps =@ps.reverse_deb_dependencies("rock-master-18.09-base-types")
            assert !deps.include?("rock-master-18.09-base-orogen-std")
        end
    end

    describe "setup_rock_osdeps" do
        before do
            file = File.join(File.dirname(__FILE__),"..","data","master-18.09-amd64.yml")
            @ps = Rock::DebianPackaging::PackageSelector.new
            @ps.load_osdeps_file(file)
        end

        describe "#initialize" do
            it "initializes the internal structures" do
                assert @ps.pkg_to_deb["base/types"] = "rock-master-18.09-base-types"
                assert @ps.deb_to_pkg["rock-master-18.09-base-types"] = "base/types"
            end

            it "computes reverse dependencies" do
                deps = @ps.reverse_dependencies("base/cmake")
                assert deps.include?("base/types")

                deps = @ps.reverse_dependencies("base/types")
                assert !deps.include?("base/orogen/std"), "base/orogen/std is not a reverse dependency of base/types"
                assert deps.include?("base/orogen/types"), "base/orogen/types is a reverse dependency of base/types"
            end
        end
    end

    describe "hierarchical_release" do
        it "load_osdeps" do
            @ps = Rock::DebianPackaging::PackageSelector.new

            file = File.join(File.dirname(__FILE__),"data","master-19.06-amd64.yml")
            @ps.load_osdeps_file(file)

            file = File.join(File.dirname(__FILE__),"data","derived-19.06-amd64.yml")
            @ps.load_osdeps_file(file)

            assert @ps.pkg_to_deb['tools/msgpack-c'] == 'otherpackage'
        end

        it "load_osdeps_no_override" do
            @ps = Rock::DebianPackaging::PackageSelector.new

            file = File.join(File.dirname(__FILE__),"data","master-19.06-amd64.yml")
            @ps.load_osdeps_file(file)

            file = File.join(File.dirname(__FILE__),"data","derived-19.06-amd64.yml")
            assert_raises do
                @ps.load_osdeps_file(file, allow_override: false)
            end
        end
    end

end

