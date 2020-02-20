require 'autoproj'
require 'minitest/autorun'

require_relative '../lib/package_selector'
require_relative '../lib/release'

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
            file = File.join(__dir__,"..","data","master-18.09-amd64.yml")
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
        before do
            # Prepare testdirectory
            @target_dir = "/tmp/rock-core-test"
            @data_dir = File.join(@target_dir, "data")

            FileUtils.rm_rf(@target_dir) if File.exists?(@target_dir)
            FileUtils.mkdir_p(@data_dir)

            FileUtils.cp_r File.join(__dir__,"data"), @target_dir
        end

        it "load_osdeps" do
            @ps = Rock::DebianPackaging::PackageSelector.new

            file = File.join(@data_dir,"master-19.06-amd64.yml")
            @ps.load_osdeps_file(file)

            file = File.join(@data_dir,"derived-19.06-amd64.yml")
            @ps.load_osdeps_file(file)

            assert @ps.pkg_to_deb['tools/msgpack-c'] == 'otherpackage'
        end

        it "load_osdeps_no_override" do
            @ps = Rock::DebianPackaging::PackageSelector.new

            file = File.join(@data_dir,"master-19.06-amd64.yml")
            @ps.load_osdeps_file(file)

            file = File.join(@data_dir,"derived-19.06-amd64.yml")
            assert_raises do
                @ps.load_osdeps_file(file, allow_override: false)
            end
        end

        it "loads the releases spec" do
            release = Rock::DebianPackaging::Release.new('master-19.06',
                                                         data_dir: @data_dir)

            assert(release.name == 'master-19.06')
            assert(release.repo_url =~ /myserver/)
            assert(release.public_key =~ /mykeyserver/)
            assert(release.hierarchy == ['master-18.01','master-19.06'])
        end

        it "uses defaults in the releases spec" do
            release = Rock::DebianPackaging::Release.new('master-18.01',
                                                         data_dir: @data_dir)
            assert(release.name == 'master-18.01')
            assert(release.repo_url =~ /rock.hb.dfki.de/)
            assert(release.public_key =~ /rock.hb.dfki.de/)
            assert(release.hierarchy == ['master-18.01'])
        end

        it "loads the release osdeps" do
            release = Rock::DebianPackaging::Release.new('master-18.01',
                                                         data_dir: @data_dir)
            release_armel = Rock::DebianPackaging::Release.new('master-18.01',
                                                         data_dir: @data_dir,
                                                         arch: "armel")

            osdeps_file = File.join(@data_dir,"master-18.01-armel.yml")
            assert_raises do
                release_armel.retrieve_osdeps_file()
            end
            assert(!File.exists?(osdeps_file))

            File.open(osdeps_file,"w") do |file|
                file.puts "---"
            end

            begin
                release.retrieve_osdeps_file()
            rescue Exception => e
                assert(false)
            end

            release = Rock::DebianPackaging::Release.new('master-20.01',
                                                         data_dir: @data_dir)
            osdeps_file = File.join(@data_dir,"master-20.01-amd64.yml")
            release.retrieve_osdeps_file()
            assert( File.exists?(osdeps_file) )
        end
    end

    describe "release update" do
        before do
            # Prepare testdirectory
            @target_dir = "/tmp/rock-core-test"
            @data_dir = File.join(@target_dir, "data")

            FileUtils.rm_rf(@target_dir) if File.exists?(@target_dir)
            FileUtils.mkdir_p(@data_dir)

            FileUtils.cp_r File.join(__dir__,"data"), @target_dir
        end

        it "update the release osdeps file" do

            release = Rock::DebianPackaging::Release.new('master-20.01',
                                                         data_dir: @data_dir)
            osdeps_file = File.join(@target_dir,"master-20.01-amd64.yml")

            # Create already existing file
            FileUtils.touch(osdeps_file)

            release.update()
            assert( File.exists?(osdeps_file) )
        end

        it "activates the release hierarchy" do
            release = Rock::DebianPackaging::Release.new('master-20.01',
                                                         data_dir: @data_dir)

            Rock::DebianPackaging::PackageSelector::activate_release(release,
                                                                     output_dir: @data_dir)
            assert( File.exists?(File.join(@data_dir, "rock-osdeps.osdeps")) )
        end
    end
end

