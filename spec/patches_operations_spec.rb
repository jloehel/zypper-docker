require_relative "helper"

describe "patch operations" do
  let(:author) { "zypper-docker test suite" }
  let(:message) { "this is a test" }

  before :all do
    @patched_image_repo = "zypper-docker-patched-image"
    @patched_image_tag  = "1.0"
    @patched_image      = "#{@patched_image_repo}:#{@patched_image_tag}"
  end

  after :all do
    if docker_image_exists?(@patched_image_repo, @patched_image_tag)
      remove_docker_image(@patched_image)
    end
  end

  context 'listing patches' do
    it 'show patch name' do
      output = Cheetah.run(
        "zypper-docker", "lp", Settings::VULNERABLE_IMAGE,
        stdout: :capture)
      expect(output).to include("openSUSE-2015-345")
      expect(output).to include("openSUSE-2015-526")
    end

    it 'can show the bugzilla number' do
      output = Cheetah.run(
        "zypper-docker", "lp", "--bugzilla", Settings::VULNERABLE_IMAGE,
        stdout: :capture)
      expect(output).to include("928394")
      expect(output).to include("940950")
    end

    it 'can filter by bugzilla number' do
      output = Cheetah.run(
        "zypper-docker", "lp", "--bugzilla=928394", Settings::VULNERABLE_IMAGE,
        stdout: :capture)
      expect(output).to include("928394")
      expect(output).not_to include("940950")
    end

    it 'can show the cve number' do
      output = Cheetah.run(
        "zypper-docker", "lp", "--cve", Settings::VULNERABLE_IMAGE,
        stdout: :capture)
      expect(output).to include('CVE-2015-1545')
      expect(output).to include('CVE-2015-1546')
    end

    it 'can filter by cve number' do
      output = Cheetah.run(
        "zypper-docker", "lp", "--cve=CVE-2015-1545", Settings::VULNERABLE_IMAGE,
        stdout: :capture)
      expect(output).not_to include('CVE-2015-1546')
      expect(output).to include('CVE-2015-1545')
    end

    it 'can filter by date' do
      output = Cheetah.run(
        "zypper-docker", "lp", "--date", "2014-12-1", Settings::VULNERABLE_IMAGE,
        stdout: :capture)
      expect(output).to include('No updates found')

      output = Cheetah.run(
        "zypper-docker", "lp", "--date", "2015-12-1", Settings::VULNERABLE_IMAGE,
        stdout: :capture)
      expect(output).to include('openSUSE-2015-345')
    end

    it 'can show the issue type' do
      output = Cheetah.run(
        "zypper-docker", "lp", "--issues", Settings::VULNERABLE_IMAGE,
        stdout: :capture)
      expect(output).to include('bugzilla')
      expect(output).to include('cve')
    end

    it 'can filter by issue type' do
      output = Cheetah.run(
        "zypper-docker", "lp", "--issues=cve", Settings::VULNERABLE_IMAGE,
        stdout: :capture)
      expect(output).not_to include('bugzilla')
      expect(output).to include('cve')
    end

    it 'filter by category name' do
      output = Cheetah.run(
        "zypper-docker", "lp", "--category", "recommended", Settings::VULNERABLE_IMAGE,
        stdout: :capture)
      expect(output).to include('openSUSE-2015-345')
    end

    context 'apply patches' do
      before(:each) do
        if docker_image_exists?(@patched_image_repo, @patched_image_tag)
          remove_docker_image(@patched_image)
        end
      end

      it 'can apply by bugzilla number' do
        Cheetah.run(
          "zypper-docker", "patch",
          "--author", author,
          "--message", message,
          "--bugzilla=928394",
          Settings::VULNERABLE_IMAGE,
          @patched_image)
        expect(docker_image_exists?(@patched_image_repo, @patched_image_tag)).to be true

        output = Cheetah.run(
          "zypper-docker", "lp", "--bugzilla=928394", @patched_image,
          stdout: :capture)
        expect(output).not_to include('928394')

        check_commit_details(author, message, @patched_image)
      end

      it 'can apply by cve number' do
        Cheetah.run(
          "zypper-docker", "patch",
          "--author", author,
          "--message", message,
          "--cve=CVE-2015-1545",
          Settings::VULNERABLE_IMAGE,
          @patched_image)
        expect(docker_image_exists?(@patched_image_repo, @patched_image_tag)).to be true

        output = Cheetah.run(
          "zypper-docker", "lp", "--cve=CVE-2015-1545", @patched_image,
          stdout: :capture)
        expect(output).not_to include('CVE-2015-1545')

        check_commit_details(author, message, @patched_image)
      end

      it 'can apply by date' do
        Cheetah.run(
          "zypper-docker", "patch",
          "--author", author,
          "--message", message,
          "--date", "2015-8-1",
          Settings::VULNERABLE_IMAGE,
          @patched_image)
        expect(docker_image_exists?(@patched_image_repo, @patched_image_tag)).to be true

        output = Cheetah.run(
          "zypper-docker", "lp", "--date", "2015-8-1", @patched_image,
          stdout: :capture)
        expect(output).not_to include('openSUSE-2015-345')
        expect(output).not_to include('openSUSE-2015-497')
        expect(output).not_to include('openSUSE-2015-526')

        check_commit_details(author, message, @patched_image)
      end

      it 'apply by category name' do
        Cheetah.run(
          "zypper-docker", "patch",
          "--author", author,
          "--message", message,
          "--category", "recommended",
          Settings::VULNERABLE_IMAGE,
          @patched_image)
        expect(docker_image_exists?(@patched_image_repo, @patched_image_tag)).to be true

        output = Cheetah.run(
          "zypper-docker", "lp", @patched_image,
          stdout: :capture)
        expect(output).not_to include('recommended')
        expect(output).to include('security')

        check_commit_details(author, message, @patched_image)
      end
    end

    it 'checks patches' do
      exception = nil

      begin
        Cheetah.run(
          "zypper-docker", "pchk", Settings::VULNERABLE_IMAGE)
      rescue Cheetah::ExecutionFailed => e
        exception = e
      end
      expect(exception).not_to be_nil
      expect(exception.status.exitstatus).to eq(101)
      expect(exception.stdout).to include('security patches')
      expect(exception.stdout).to include('patches needed')
    end
  end

  context "analyze a running container" do
    before :all do
      @keep_alpine = docker_image_exists?("alpine", "latest")
      pull_image("alpine:latest") unless @keep_alpine

      @vul_container           = unique_name("vulnerable_container")
      @patched_container       = unique_name("patched_container")
      @not_suse_container      = unique_name("not_suse_container")
      @containers_to_terminate = []

      start_background_container(Settings::VULNERABLE_IMAGE, @vul_container)
      @containers_to_terminate << @vul_container

      expect(docker_image_exists?(@patched_image_repo, @patched_image_tag)).to be true
      start_background_container(@patched_image, @patched_container)
      @containers_to_terminate << @patched_container

      start_background_container("alpine:latest", @not_suse_container)
      @containers_to_terminate << @not_suse_container
    end

    after :all do
      @containers_to_terminate.each do |container|
        kill_and_remove_container(container)
      end

      remove_docker_image("alpine:latest") unless @keep_alpine
    end

    it "finds the pending updates of a SUSE-based image" do
      output = Cheetah.run("zypper-docker", "lpc", @vul_container, stdout: :capture)
      expect(output).to include("openSUSE-2015-345")
    end

    it "does not find updates for patched containers" do
      output = Cheetah.run("zypper-docker", "lpc", @patched_container, stdout: :capture)
      expect(output).not_to include("openSUSE-2015-345")
    end

    it "reports non-SUSE containers" do
      exception = nil

      begin
        Cheetah.run(
          "zypper-docker", "lpc", @not_suse_container)
      rescue Cheetah::ExecutionFailed => e
        exception = e
      end
      expect(exception).not_to be_nil
      expect(exception.status.exitstatus).to eq(1)
      expect(exception.stderr).to include("alpine:latest which is not a SUSE system")
    end
  end

end
