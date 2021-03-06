require "cheetah"
require "pathname"

class Settings
  VULNERABLE_IMAGE_REPO = "zypper-docker-tests-vulnerable-image"
  VULNERABLE_IMAGE_TAG = "0.1"
  VULNERABLE_IMAGE = "#{VULNERABLE_IMAGE_REPO}:#{VULNERABLE_IMAGE_TAG}"

end

module SpecHelper
  def docker_image_exists?(repo, tag)
    if tag == "" || tag.nil?
      tag = "latest"
    end
    output = Cheetah.run("docker", "images", repo, stdout: :capture)
    output.include?(tag)
  end

  def pull_image(image)
    system("docker pull #{image}")
  end

  def container_running?(container)
    output = Cheetah.run("docker", "ps", stdout: :capture)
    output.include?(container)
  end

  def kill_and_remove_container(container)
    Cheetah.run("docker", "kill", container) if container_running?(container)
    Cheetah.run("docker", "rm", "-f", container)
  rescue Cheetah::ExecutionFailed => e
    puts "Error while running: #{e.commands}"
    puts "Stdout: #{e.stdout}"
    puts "Stderr: #{e.stderr}"
  end

  def ensure_vulnerable_image_exists
    return if docker_image_exists?(Settings::VULNERABLE_IMAGE_REPO, Settings::VULNERABLE_IMAGE_TAG)

    # Do not use cheetah, we want live streaming of what is happening
    puts "Building #{Settings::VULNERABLE_IMAGE}"
    cmd = "docker build" \
      " -f #{File.join(Pathname.new(__FILE__).parent.parent, "docker/Dockerfile-vulnerable-image")}" \
      " -t #{Settings::VULNERABLE_IMAGE}" \
      " #{Pathname.new(__FILE__).parent.parent}"
    puts cmd
    system(cmd)
    exit(1) if $? != 0
  end

  def remove_docker_image(image)
    Cheetah.run("docker", "rmi", "-f", image)
  end

  def docker_image_commit_details(image)
    author = Cheetah.run("docker", "inspect", "--format='{{.Author}}'",  image, stdout: :capture)
    message = Cheetah.run("docker", "inspect", "--format='{{.Comment}}'", image, stdout: :capture)

    return author, message
  end

  def check_commit_details(expected_author, expected_message, image)
    actual_author, actual_message = docker_image_commit_details(image)
    expect(expected_author.chomp).to eq(actual_author.chomp)
    expect(expected_message.chomp).to eq(actual_message.chomp)
  end

  # Makes the given name unique by adding the current time to it.
  def unique_name(name)
    "#{name}_#{Time.now.to_i}"
  end

  # Start a container running in the background doing a NOP (a simple sleep)
  def start_background_container(image, container_name, solve_conflicts=true)
    Cheetah.run(
      "docker", "run",
      "-d",
      "--entrypoint", "env",
      "--name", container_name,
      image,
      "sh", "-c", "sleep 1h")
  end

end

RSpec.configure do |config|
  config.include(SpecHelper)

  config.before :all do
    ensure_vulnerable_image_exists
  end
end
