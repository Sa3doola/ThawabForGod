#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the local `ArabicText` package to the Xcode project and links it into the app.
#
# Run from the repository root, once:
#
#     ruby Tools/add_arabic_text_package.rb
#
# It is a script rather than a set of instructions because CLAUDE.md forbids hand-editing
# `project.pbxproj`, and the `xcodeproj` gem writes the same structures Xcode does. It is
# idempotent: run again and it reports that there is nothing to do.
#
# What it sets up, and why:
#
#   * an `XCLocalSwiftPackageReference` to `Packages/ArabicText` — a path, not a URL, because the
#     package lives in this repository and `Tools/QuranBuilder` depends on the same folder;
#   * the `ArabicText` product linked into the **app target only**. `Core/Search` is the one
#     caller, and `Core/` is compiled into the app alone; the widget and the notification
#     extension search nothing, so they do not pay for it.

require 'xcodeproj'

PROJECT = 'ThawabForGod.xcodeproj'
APP     = 'ThawabForGod'
PATH    = 'Packages/ArabicText'
PRODUCT = 'ArabicText'

project = Xcodeproj::Project.open(PROJECT)
app = project.targets.find { |t| t.name == APP } or abort "No target named #{APP}."
root = project.root_object

reference = root.package_references.find do |ref|
  ref.isa == 'XCLocalSwiftPackageReference' && ref.relative_path == PATH
end

linked = app.package_product_dependencies.any? { |dep| dep.product_name == PRODUCT }

if reference && linked
  puts "#{PRODUCT} is already referenced and linked into #{APP} — nothing to do."
  exit 0
end

unless reference
  reference = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  reference.relative_path = PATH
  root.package_references << reference
end

unless linked
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.product_name = PRODUCT
  dependency.package = reference
  app.package_product_dependencies << dependency

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  app.frameworks_build_phase.files << build_file
end

project.save

puts "Referenced #{PATH} and linked #{PRODUCT} into #{APP}."
puts 'Next: xcodebuild build -scheme ThawabForGod -project ThawabForGod.xcodeproj ' \
     "-destination 'platform=iOS Simulator,name=iPhone 17' -quiet"
