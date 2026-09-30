#!/usr/bin/env ruby
# frozen_string_literal: true

# Declares Noor's alternate app icons in the app target's build settings.
#
# Run from the repository root, once, and again whenever an icon is added or withdrawn:
#
#     ruby Tools/add_alternate_app_icons.rb
#
# It is a script rather than a set of instructions because CLAUDE.md forbids hand-editing
# `project.pbxproj`, and the `xcodeproj` gem writes the same structures Xcode does. It is
# idempotent: run again and it reports that there is nothing to do.
#
# What it sets, and why:
#
#   * `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` — the Icon Composer bundles in
#     `ThawabForGod/Resources/` are all compiled, but only the one named by
#     `ASSETCATALOG_COMPILER_APPICON_NAME` is the icon. Naming the others here is what makes
#     actool write them into the built Info.plist under `CFBundleIcons` → `CFBundleAlternateIcons`,
#     and `UIApplication.setAlternateIconName(_:)` refuses any name that is not listed there.
#
#   * Conditioned on the iOS SDKs only. macOS has no alternate-icon API — the Settings row does
#     not exist on the Mac — so the Mac build has no reason to carry three more icons.
#
# The list must match `AppIconChoice.alternateIconName`. No compiler checks the two against each
# other, so `AppIconTests` reads the built Info.plist and does.

require 'xcodeproj'

PROJECT = 'ThawabForGod.xcodeproj'
APP     = 'ThawabForGod'
ICONS   = %w[AppIcon-Green AppIcon-Night AppIcon-Sand].freeze
KEYS    = %w[
  ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES[sdk=iphoneos*]
  ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES[sdk=iphonesimulator*]
].freeze

project = Xcodeproj::Project.open(PROJECT)
target = project.targets.find { |t| t.name == APP } or abort "No target named #{APP}."

value = ICONS.join(' ')
changed = false

target.build_configurations.each do |config|
  KEYS.each do |key|
    next if config.build_settings[key] == value

    config.build_settings[key] = value
    changed = true
  end
end

unless changed
  puts "Alternate icons already declared (#{value}) — nothing to do."
  exit 0
end

project.save

puts "Declared alternate icons: #{value}."
puts 'Next: xcodebuild build -scheme ThawabForGod -project ThawabForGod.xcodeproj ' \
     "-destination 'platform=iOS Simulator,name=iPhone 17' -quiet"
