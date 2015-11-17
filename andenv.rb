#!/usr/bin/env ruby
#
# Download Android SDK locally for situations where you don't have access to the build
# server (i.e. CI systems)
#

####
#### CONFIG SECTION
####


#
# ANDROID_SDK_PREFIX is the first part of the tgz or zip file you want to download.
#                    tgz for Linux, zip for mac
#
ANDROID_SDK_PREFIX = 'android-sdk_r24.4.1'

#
# The BuildTools version used by your project
#
ANDROID_BUILD_TOOLS = 'build-tools-23.0.1'

#
# The SDK version used to compile your project
#
ANDROID_PROJECT_SDK = 'android-23'

#
# Additional packages you want to install
#
ANDROID_ADDITIONALS = [ 'extra-android-support', 'extra-google-m2repository', 'extra-android-m2repository' ]

####
#### END CONFIG
####

require 'pty'
require 'expect'
require 'net/http'
require 'uri'
require 'fileutils'

ENVROOT = Dir.pwd + "/.andenv"

module OS
  def OS.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  def OS.mac?
   (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  def OS.unix?
    !OS.windows?
  end

  def OS.linux?
    OS.unix? and not OS.mac?
  end
end

module SafePty
    def self.spawn command, &block
        PTY.spawn(command) do |r,w,p|
            begin
                yield r,w,p
            rescue Errno::EIO
            ensure
                Process.wait p
            end
        end
        $?.exitstatus
    end
end


USR = "#{ENVROOT}/usr"
USRLOCAL = "#{USR}/local"
DOWNLOADS = "#{ENVROOT}/downloads"

if OS.mac?
    SDKTGZ_URL = "http://dl.google.com/android/#{ANDROID_SDK_PREFIX}-macosx.zip"
    ANDROID_SDK = "#{USRLOCAL}/android-sdk-macosx"
elsif OS.linux?
    SDKTGZ_URL = "http://dl.google.com/android/#{ANDROID_SDK_PREFIX}-linux.tgz"
    ANDROID_SDK = "#{USRLOCAL}/android-sdk-linux"
end


FileUtils::mkdir_p "#{USRLOCAL}"
FileUtils::mkdir_p "#{DOWNLOADS}"

sdkuri = URI.parse(SDKTGZ_URL)
SDKTGZ_LOCAL = "#{DOWNLOADS}/#{File.basename(sdkuri.path)}"
if !File.file?(SDKTGZ_LOCAL)
    puts "Downloading #{SDKTGZ_URL}"
    Net::HTTP.start(sdkuri.host) do |http|
        resp = http.get(sdkuri.path)
        open(SDKTGZ_LOCAL, "wb") do |file|
            file.write(resp.body)
        end
    end
end

if !File.exist?(ANDROID_SDK)
    puts "Extracting #{SDKTGZ_LOCAL}"
    if OS.mac?
        system("unzip -o -d \"#{USRLOCAL}\" \"#{SDKTGZ_LOCAL}\"")
    else
        system("tar xfz \"#{SDKTGZ_LOCAL}\" -C \"#{USRLOCAL}\"")
    end
end

ENV['ANDROID_HOME'] = "#{ANDROID_SDK}"
ENV['ANDROID_SDK_HOME'] = "#{ANDROID_SDK}"
ENV['PATH'] = "#{ANDROID_SDK}/tools:#{ANDROID_SDK}/platform-tools:#{ENV['PATH']}"

#$expect_verbose = true
def doAndAccept(cmd)
    puts cmd
    SafePty.spawn(cmd) do |reader, writer, pid|
        loop do
            reader.expect(/.*Do you accept the license.*:/)
            writer.printf("y\r")
        end
    end
end

doAndAccept("android update sdk --no-ui --filter platform-tool-23.1")
doAndAccept("android update sdk --no-ui --filter tool")
doAndAccept("android update sdk --no-ui --filter #{ANDROID_BUILD_TOOLS} --all")
doAndAccept("android update sdk --no-ui --filter #{ANDROID_PROJECT_SDK}")

ANDROID_ADDITIONALS.each do |additional|
    doAndAccept("android update sdk --no-ui --filter #{additional} --all")
end

puts "Android environment installed to #{ANDROID_SDK}"
puts "Run the following commands to use the new environment"
puts ""
puts "export ANDROID_HOME=\"#{ANDROID_SDK}\""
puts "export PATH=\"#{ANDROID_SDK}/tools:#{ANDROID_SDK}/platform-tools:$PATH\""

