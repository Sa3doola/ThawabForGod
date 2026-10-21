#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds `ar` to the project's `knownRegions`.
#
# Run from the repository root:
#
#     ruby Tools/add_arabic_known_region.rb
#
# Why (docs/quran-migration/BUGS.md, B7): the plan asked for `ar` among the project's declared
# regions, and it is harmless. It does NOT make the Mac window mirror: with it declared, AppKit still
# reports a left-to-right `NSApp.userInterfaceLayoutDirection` under `-AppleLanguages (ar)`. The Mac
# gets its mirroring from `LocalizedModifier` instead. It is a script because CLAUDE.md forbids
# hand-editing `project.pbxproj`;
# the `xcodeproj` gem writes the same structures Xcode does. Idempotent.

require 'xcodeproj'

project = Xcodeproj::Project.open('ThawabForGod.xcodeproj')
regions = project.root_object.known_regions

if regions.include?('ar')
  puts 'knownRegions already contains ar: nothing to do.'
else
  project.root_object.known_regions = regions + ['ar']
  project.save
  puts "knownRegions is now #{project.root_object.known_regions.inspect}."
end
