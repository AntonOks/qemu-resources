#!/usr/bin/env ruby

require "forwardable"
require "minitest/autorun"
require "open3"
require "rubygems"
require "rubygems/package"
require "set"

def execute(command, *args)
  stdout, status = Open3.capture2(command, *args)
  raise "Failed to executed command: #{command} #{args.join(' ')}" unless status.success?
  stdout
end

def qemu_path(architecture)
  "qemu/build/qemu-system-#{architecture}"
end

def assert_qemu_system(architecture, firmwares:)
  validator = QemuSystemValidator.new(architecture, firmwares)
  assert validator.valid?, validator.message
end

def assert_only_system_dependencies(architecture)
  return unless QemuSystemValidator.host_os == "macos"

  allowed_prefixes = Set.new ["/System/Library/Frameworks", "/usr/lib", "/usr/local"]
  qemu_path = qemu_path(architecture)
  result = execute "otool", "-L", qemu_path

  non_system_dependecies = result
      .split("\n")
      .drop(1)
      .map(&:strip)
      .reject { |path| allowed_prefixes.any? { path.start_with?(_1) } }
      .map { _1.split.first }

  assert non_system_dependecies.empty?, %("#{qemu_path}" is linked with the following non-system dependencies:\n#{non_system_dependecies.join("\n")})
end

def assert_statically_linked(architecture)
  return unless QemuSystemValidator.host_os == "linux"

  qemu_path = qemu_path(architecture)
  result = execute "file", qemu_path
  statically_linked = result.include?("static-pie linked") || result.include?("statically linked")
  assert statically_linked, %("#{qemu_path}" is not statically linked:\n#{result})
end

describe "resources" do
  describe "qemu-system" do
    describe "x86_64" do
      it "contains the correct file structure for x86_64" do
        assert_qemu_system "x86_64", firmwares: %w[
          bios-256k.bin
          efi-e1000.rom
          efi-virtio.rom
          kvmvapic.bin
          vgabios-stdvga.bin
          uefi.fd
        ]
      end

      it "is only linked with system dependencies" do
        assert_only_system_dependencies "x86_64"
      end

      it "is statically linked" do
        assert_statically_linked "x86_64"
      end
    end

    describe "arm64" do
      it "contains the correct file structure for arm64" do
        assert_qemu_system "aarch64", firmwares: %w[
          efi-e1000.rom
          efi-virtio.rom
          uefi.fd
          linaro_uefi.fd
        ]
      end

      it "is only linked with system dependencies" do
        assert_only_system_dependencies "aarch64"
      end

      it "is statically linked" do
        assert_statically_linked "aarch64"
      end
    end
  end
end

class QemuSystemValidator
  attr_reader :firmwares

  def initialize(architecture, firmwares)
    @architecture = architecture
    @firmwares = firmwares.sort
  end

  def self.host_os
    @host_os ||= case Gem::Platform.local.os
      when "darwin"
        "macos"
      when "linux"
        "linux"
      else
        raise "Unsupported platform: #{Gem::Platform.local.os}"
      end
  end

  def valid?
    @valid ||= qemu_binary? && firmware_matching?
  end

  def message
    message_formatter.format
  end

  def tar_file
    @tar_file ||= TarFile.for(architecture: architecture, host_os: host_os)
  end

  def extra
    @extra ||= tar_file.firmwares - firmwares
  end

  def missing
    @missing ||= firmwares - tar_file.firmwares
  end

  private

  attr_reader :architecture

  def qemu_binary?
    tar_file.qemu_binary.any?
  end

  def firmware_matching?
    extra.empty? && missing.empty?
  end

  def message_formatter
    @message_formatter ||= MessageFormatter.new(self)
  end

  def host_os
    self.class.host_os
  end

  class TarFile
    def self.for(architecture:, host_os:)
      new("qemu-system-#{architecture}-#{host_os}.tar")
    end

    def initialize(filename)
      @filename = filename
    end

    attr_reader :filename

    def paths
      @paths ||= File.open(filename) do |io|
        tar_files = []

        Gem::Package::TarReader.new(io) do |tar|
          tar_files = tar
          .filter(&:file?)
          .map(&:full_name)
          .map { _1.delete_prefix("./") }
          .sort
        end

        tar_files
      end
    end

    def firmware_paths
      @firmware_paths ||= paths.filter { _1.start_with?(firmware_directory) }
    end

    def qemu_binary
      @qemu_binary ||= paths.filter { _1.start_with?("bin/qemu") }
    end

    def firmwares
      @firmwares ||= firmware_paths.map { _1.delete_prefix(firmware_directory) }
    end

    def firmware_directory
      "share/qemu/"
    end
  end

  class MessageFormatter
    extend Forwardable

    def initialize(validator)
      @validator = validator
    end

    def format
      expected.concat([""], actual, [""], diff).join("\n")
    end

    private

    def_delegators :@validator, :tar_file, :firmwares, :missing, :extra

    def expected
      [
        "Expected '#{tar_file.filename}' to contain:",
        binary_message,
        firmware_message,
      ]
    end

    def actual
      ["Actual:"] + tar_file.paths
    end

    def diff
      missing = to_full_path(self.missing)
      extra = to_full_path(self.extra)

      diff = to_full_path(firmwares)
        .concat(to_full_path(tar_file.firmwares))
        .uniq
        .map { missing.include?(_1) ? "-#{_1}" : _1 }
        .map { extra.include?(_1) ? "+#{_1}" : _1 }

      ["Diff:"] + diff
    end

    def binary_message
      tar_file.qemu_binary
    end

    def firmware_message
      to_full_path(firmwares).join("\n")
    end

    def to_full_path(array)
      array.map { File.join(tar_file.firmware_directory, _1) }
    end
  end
end
