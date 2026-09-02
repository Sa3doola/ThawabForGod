#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the `NoorNotificationContent` target to the Xcode project.
#
# Run once, from the repository root:
#
#     ruby Tools/add_notification_content_extension.rb
#
# It is here rather than in a set of instructions because CLAUDE.md forbids hand-editing
# `project.pbxproj`, and the `xcodeproj` gem writes the same structures Xcode does. It is
# idempotent: run again and it reports that the target already exists.
#
# What it sets up, and why each piece is needed:
#
#   * a `com.apple.product-type.app-extension` target with the notification-content extension
#     point, embedded in the app's `Embed Foundation Extensions` phase;
#   * the `Shared` file-system synchronized root group added to its membership, because the card
#     reads `ReminderPresentation`, `Theme`, `DayRampBackground`, `LocaleTimeFormattingService`
#     and `SharedDefaults` — all of which live there;
#   * the **Adhan** package product linked, because a synchronized root group is all-or-nothing
#     per target and `Shared/PrayerTimes/Data/PrayerTimeEngine` imports it. The same trade the
#     widget extension already makes;
#   * the App Group entitlement, so the card can read the reader's digits, hour cycle and accent
#     out of the same suite the widget does;
#   * iOS only, and enforced in the *dependency graph* rather than only in build settings.
#     `SUPPORTED_PLATFORMS` alone is not enough: the app embeds this target and depends on it, so
#     a macOS build would try to build it anyway and fail on the iOS provisioning profile. Both
#     the embed build file and the target dependency carry a `platformFilters` of `["ios"]`, which
#     is how Xcode itself expresses "this piece of the app exists on one platform".

require 'xcodeproj'

PROJECT = 'ThawabForGod.xcodeproj'
TARGET  = 'NoorNotificationContent'
APP     = 'ThawabForGod'
GROUP   = 'Shared'

project = Xcodeproj::Project.open(PROJECT)

if project.targets.any? { |t| t.name == TARGET }
  puts "#{TARGET} already exists — nothing to do."
  exit 0
end

app = project.targets.find { |t| t.name == APP } or abort "No #{APP} target."
widget = project.targets.find { |t| t.name == 'NoorWidgetsExtension' } or abort 'No widget target.'

target = project.new_target(
  :app_extension, TARGET, :ios, '17.0', project.products_group, :swift
)

# Build settings, taken from the widget extension so the two extensions cannot drift on the
# language mode, the actor-isolation default or the deployment target.
target.build_configurations.each do |config|
  widget_config = widget.build_configurations.find { |c| c.name == config.name }

  %w[
    CODE_SIGN_STYLE CURRENT_PROJECT_VERSION DEVELOPMENT_TEAM MARKETING_VERSION
    SWIFT_APPROACHABLE_CONCURRENCY SWIFT_DEFAULT_ACTOR_ISOLATION SWIFT_EMIT_LOC_STRINGS
    SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY SWIFT_VERSION STRING_CATALOG_GENERATE_SYMBOLS
    TARGETED_DEVICE_FAMILY SKIP_INSTALL GENERATE_INFOPLIST_FILE
  ].each do |key|
    value = widget_config.build_settings[key]
    config.build_settings[key] = value unless value.nil?
  end

  config.build_settings.merge!(
    'CODE_SIGN_ENTITLEMENTS' => "#{TARGET}.entitlements",
    'INFOPLIST_FILE' => "#{TARGET}/Info.plist",
    'INFOPLIST_KEY_CFBundleDisplayName' => 'Noor Reminders',
    'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.Sa3dola.ThawabForGod.NotificationContent',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'REGISTER_APP_GROUPS' => 'YES',
    # iOS only: there is no notification-content extension point on macOS, and listing macosx
    # here would make the Mac build try to embed something that cannot exist.
    'SUPPORTED_PLATFORMS' => 'iphoneos iphonesimulator',
    'SUPPORTS_MACCATALYST' => 'NO',
    'SDKROOT' => 'iphoneos',
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'
    ]
  )
end

# The extension's own sources, as a synchronized root group — the same mechanism every other
# folder in this project uses, so a new file is picked up without touching the project again.
own_group = project.new(Xcodeproj::Project::Object::PBXFileSystemSynchronizedRootGroup)
own_group.path = TARGET
own_group.source_tree = '<group>'
project.main_group << own_group

# The Info.plist is a build setting, not a resource — it must not also be copied into the bundle.
exception = project.new(Xcodeproj::Project::Object::PBXFileSystemSynchronizedBuildFileExceptionSet)
exception.target = target
exception.membership_exceptions = ['Info.plist']
own_group.exceptions << exception

shared = project.main_group.children.find do |child|
  child.is_a?(Xcodeproj::Project::Object::PBXFileSystemSynchronizedRootGroup) && child.path == GROUP
end
abort "No #{GROUP} synchronized group." if shared.nil?

target.file_system_synchronized_groups << own_group
target.file_system_synchronized_groups << shared

# Adhan, because `Shared` carries `PrayerTimeEngine` and a synchronized group is all-or-nothing.
adhan = widget.package_product_dependencies.find { |d| d.product_name == 'Adhan' }
if adhan
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.package = adhan.package
  dependency.product_name = 'Adhan'
  target.package_product_dependencies << dependency
  target.frameworks_build_phase.add_file_reference(
    project.new(Xcodeproj::Project::Object::PBXBuildFile).tap { |f| f.product_ref = dependency }
  ) rescue nil
end

# Embed it in the app, and build it first.
embed = app.build_phases.find do |phase|
  phase.respond_to?(:symbol_dst_subfolder_spec) &&
    phase.symbol_dst_subfolder_spec == :plug_ins &&
    phase.name.to_s.include?('Extensions')
end

embed ||= app.new_copy_files_build_phase('Embed Foundation Extensions').tap do |phase|
  phase.symbol_dst_subfolder_spec = :plug_ins
end

embed.add_file_reference(target.product_reference).tap do |file|
  file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  # Without this the Mac build copies — and therefore builds — an extension whose extension point
  # does not exist on macOS, and fails signing it against an iOS profile.
  file.platform_filters = ['ios']
end

app.add_dependency(target)
app.dependencies.last.platform_filters = ['ios']

project.save

puts "Added #{TARGET}."
puts 'Next: xcodebuild build -scheme ThawabForGod -destination "platform=iOS Simulator,name=iPhone 17"'
