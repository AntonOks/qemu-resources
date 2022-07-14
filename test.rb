#!/usr/bin/env ruby

require "forwardable"
require "minitest/autorun"
require "rubygems"
require "rubygems/package"

def assert_qemu_system(architecture, firmwares:)
  validator = QemuSystemValidator.new(architecture, firmwares)
  assert validator.valid?, validator.message
end

describe "resources" do
  describe "qemu-system" do
    describe "x86_64" do
      it "contains the correct file structure for x86_64" do
        uefi = Gem::Platform.local.os == "darwin" ? [] : ["OVMF.fd"]

        assert_qemu_system "x86_64", firmwares: %w[
          bios-256k.bin
          efi-e1000.rom
          efi-virtio.rom
          kvmvapic.bin
          vgabios-stdvga.bin
        ].concat(uefi)
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

  def valid?
    @valid ||= qemu_binary? && firmware_maching?
  end

  def message
    message_formatter.format
  end

  def tar_file
    @tar_file ||= TarFile.for(architecture: architecture, host_os: host_os)
  end

  private

  attr_reader :architecture

  def qemu_binary?
    tar_file.qemu_binary.any?
  end

  def firmware_maching?
    firmwares.all? { tar_file.firmwares.include?(_1) }
  end

  def message_formatter
    @message_formatter ||= MessageFormatter.new(self)
  end

  def host_os
    @host_os ||= case Gem::Platform.local.os
      when "darwin"
        "macos"
      when "linux"
        "linux"
      else
        raise "Unsupported platform: #{Gem::Platform.local.os}"
      end
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
      expected.concat(actual).join("\n")
    end

    private

    def_delegators :@validator, :tar_file, :firmwares

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

    def binary_message
      tar_file.qemu_binary
    end

    def firmware_message
      firmwares
        .map { File.join(tar_file.firmware_directory, _1) }
        .join("\n")
    end
  end
end
