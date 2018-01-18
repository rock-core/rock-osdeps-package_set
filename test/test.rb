require 'autoproj'
require 'minitest/autorun'

require_relative '../lib/package_selector'

module Rock
    describe "setup_rock_osdeps" do
        before do
            file = File.join(File.dirname(__FILE__),"..","data","master-17.06-amd64.yml")
            @ps = Rock::DebianPackaging::PackageSelector.new
            @ps.load_osdeps_file(file)
        end

        describe "#initialize" do
            it "initializes the internal structures" do
                assert @ps.pkg_to_deb["base/types"] = "rock-master-17.06-base-types"
                assert @ps.deb_to_pkg["rock-master-17.06-base-types"] = "base/types"
            end

            it "computes reverse dependencies" do
                deps = @ps.reverse_dependencies("base/cmake")
                assert deps.include?("base/types")

                deps = @ps.reverse_dependencies("base/types")
                assert !deps.include?("base/orogen/std"), "base/orogen/std is a reverse dependency of base/types"
                assert deps.include?("base/orogen/types"), "base/orogen/types is a reverse dependency of base/types"
            end
        end
    end
end

