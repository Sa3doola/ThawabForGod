#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds `ar` to the project's `knownRegions`.
#
# Run from the repository root:
#
#     ruby Tools/add_arabic_known_region.rb
#
# Why (docs/quran-migration/BUGS.md, B7): the String Catalog ships Arabic strings without the region
# being declared, so iOS picks Arabic and mirrors. A sandboxed Mac app launched in Arabic got the
# Arabic text but an unmirrored window (sidebar, toolbar and the Quran's side panel on the left-to-right
# side). AppKit decides the window's direction from the *project's* declared localisations, so the
# region has to be declared. It is a script because CLAUDE.md forbids hand-editing `project.pbxproj`;
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
