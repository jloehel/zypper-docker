require_relative "helper"

describe "update operations" do
  let(:author) { "zypper-docker test suite" }
  let(:message) { "this is a test" }

  before :all do
    @patched_image_repo = "zypper-docker-patched-image"
    @patched_image_tag  = unique_name("1.0")
    @patched_image      = "#{@patched_image_repo}:#{@patched_image_tag}"
  end

  after :all do
    if docker_image_exists?(@patched_image_repo, @patched_image_tag)
      remove_docker_image(@patched_image)
    end
  end

  it "lists updates of an image" do
    output = Cheetah.run("zypper-docker", "lu", Settings::VULNERABLE_IMAGE, stdout: :capture)
    expect(output).to include("alsa-utils")
  end

  context "applying updates" do
    it "creates a new image with all the updates applied" do
      if docker_image_exists?(@patched_image_repo, @patched_image_tag)
        remove_docker_image(@patched_image)
      end

      Cheetah.run(
        "zypper-docker", "up",
        "--author", author,
        "--message", message,
        Settings::VULNERABLE_IMAGE,
        @patched_image)

      expect(docker_image_exists?(@patched_image_repo, @patched_image_tag)).to be true
      output = Cheetah.run("zypper-docker", "lu", @patched_image, stdout: :capture)
      expect(output).not_to include("alsa-utils")

      check_commit_details(author, message, @patched_image)
    end

    it "refuses to overwrite an existing image while doing an update" do
      expect(docker_image_exists?(@patched_image_repo, @patched_image_tag)).to be true

      expect {
        Cheetah.run(
          "zypper-docker", "up",
          "--author", author,
          "--message", message,
          Settings::VULNERABLE_IMAGE,
        @patched_image)
      }.to raise_error(Cheetah::ExecutionFailed)
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
      output = Cheetah.run("zypper-docker", "luc", @vul_container, stdout: :capture)
      expect(output).to include("alsa-utils")
    end

    it "does not find updates for patched containers" do
      output = Cheetah.run("zypper-docker", "luc", @patched_container, stdout: :capture)
      expect(output).not_to include("alsa-utils")
    end

    it "reports non-SUSE containers" do
      exception = nil

      begin
        Cheetah.run(
          "zypper-docker", "luc", @not_suse_container)
      rescue Cheetah::ExecutionFailed => e
        exception = e
      end
      expect(exception).not_to be_nil
      expect(exception.status.exitstatus).to eq(1)
      expect(exception.stderr).to include("alpine:latest which is not a SUSE system")
    end
  end
end
