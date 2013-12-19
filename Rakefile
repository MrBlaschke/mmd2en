# encoding: UTF-8
$:.push File.join(File.dirname(__FILE__), 'ext')

require 'bundler/setup'
require 'rake/clean'
require 'rake/mustache_task'
require 'rake/osx/bundle_editor_task'
require 'rake/testtask'
require 'rake/version_task'
require 'rake/zip_task'
require 'shellwords'
require 'version'
require 'version/conversions'
require 'yaml'

def version
  Version.current
end


# CONSTANTS
# ---------
BASE_NAME     = 'mmd2en'
FULL_NAME     = 'MultiMarkdown → Evernote'

# Build system directory structure
BASE_DIR      = File.join(File.expand_path(File.dirname(__FILE__)))
LIB_DIR       = File.join(BASE_DIR, 'lib')
BUILD_DIR     = File.join(BASE_DIR, 'build')
PACKAGE_DIR   = File.join(BASE_DIR, 'packages')

# Core scripts
MAIN_SCRIPT   = File.join(BASE_DIR, "#{BASE_NAME}.rb")
LIB_SCRIPTS   = FileList.new(File.join(LIB_DIR, '*.rb'))
ALL_SCRIPTS   = LIB_SCRIPTS.dup.push(MAIN_SCRIPT)

# Service provider app
APP_BUNDLE    = File.join(BUILD_DIR, "#{FULL_NAME}.app")
APP_BUNDLE_ID = "net.kopischke.#{BASE_NAME}"
APP_DIR       = File.join(PACKAGE_DIR, 'service')
APP_TEMPLATE  = File.join(APP_DIR, "#{BASE_NAME}.platypus")
APP_SCRIPT    = File.join(APP_DIR, "#{BASE_NAME}.bash")
APP_YAML_DATA = FileList.new(File.join(APP_DIR, "#{BASE_NAME}.*.yaml"))

# Automator action
ACTION_BUNDLE = File.join(BUILD_DIR, "#{BASE_NAME}.action")
ACTION_DIR    = File.join(PACKAGE_DIR, 'automator')
ACTION_XCODE  = File.join(ACTION_DIR, "#{BASE_NAME}.xcodeproj")
ACTION_SCRIPT = File.join(PACKAGE_DIR, 'automator', BASE_NAME, 'main.command')

# Required components
MMD_BIN_DIR   = File.join(PACKAGE_DIR, 'multimarkdown', 'bin')
MMD_BIN       = FileList.new(File.join(MMD_BIN_DIR, 'multimarkdown'), File.join(MMD_BIN_DIR, 'LICENSE'))

# Package upload contents
PACKAGES      = [APP_BUNDLE, ACTION_BUNDLE]
PACKAGE_TASKS = [:app, :automator]


# TASKS
# -----
# rake clean
CLEAN.include(APP_TEMPLATE)

# rake clobber
CLOBBER.include(File.join(BUILD_DIR, '*'))

# rake test
Rake::TestTask.new do |t|
  t.libs.push 'lib'
  t.test_files = FileList['test/*_test.rb']
  t.verbose    = true
end

# rake version[:...]
Rake::VersionTask.new do |t|
	t.with_git     = true
	t.with_git_tag = true
end

# rake automator[:prepare]
Rake::SmartFileTask.new(ACTION_SCRIPT, MAIN_SCRIPT) do |t|
  t.verbose    = true
  t.named_task = {:'automator:prepare' => 'Update main script for Automator action.'}
  t.action     = ->(*_) {
    # Generate main.command and make executable (Action will fail if the script is not x!)
    main_script = ACTION_SCRIPT.shellescape
    %x{echo '#!/usr/bin/ruby -KuW0' | cat - #{MAIN_SCRIPT.shellescape} > #{main_script} && chmod +x #{main_script}}
    fail "Generation of '#{ACTION_SCRIPT}' failed with status #{$?.exitstatus}." unless $?.exitstatus == 0
  }
end

Rake::SmartFileTask.new(ACTION_BUNDLE, [ACTION_SCRIPT, *LIB_SCRIPTS, ACTION_XCODE]) do |t|
  t.verbose = true
  t.action  = ->(*_) {
    build_env   = {'CONFIGURATION_BUILD_DIR' => BUILD_DIR.shellescape}.map {|k,v| "#{k}=#{v}" }.join(' ')
    project_dir = ACTION_XCODE.pathmap('%d').shellescape
    %x{cd #{project_dir}; xcodebuild -scheme '#{BASE_NAME}' -configuration 'Release' #{build_env}}
  }
end

Rake::OSX::BundleEditorTask.new(:automator, ACTION_BUNDLE) do |t|
  t.description = 'Generate Automator action.'
  t.verbose     = true
  t.set_version = version.to_friendly
  t.set_build   = version.to_s
end

# rake platypus
Rake::MustacheTask.new(APP_TEMPLATE) do |t|
  t.named_task = {platypus: 'Generate Platypus template for OS X Service provider application'}
  t.verbose    = true
  t.data       = {
    name:     FULL_NAME,
    id:       APP_BUNDLE_ID,
    includes: [MAIN_SCRIPT, "#{LIB_DIR}#{File::SEPARATOR}", "#{MMD_BIN_DIR}#{File::SEPARATOR}"].map {|e| {path: e} },
    icon:     File.join(APP_DIR, "#{BASE_NAME}.icns"),
    script:   APP_SCRIPT,
    version:  version.to_s,
    platypus: '/usr/local/share/platypus'
  }
end

# rake app
Rake::SmartFileTask.new(APP_BUNDLE) do |t|
  t.verbose = true
  t.base    = [*ALL_SCRIPTS, APP_TEMPLATE, APP_SCRIPT, *APP_YAML_DATA, *MMD_BIN, BUILD_DIR]
  t.action  = ->(*_){
    FileUtils.rm_r(APP_BUNDLE) if File.exist?(APP_BUNDLE) # Platypus’ overwrite flag `-y` is a noop as of 4.8
    puts "Generating app bundle from Platypus template '#{APP_TEMPLATE.pathmap('%f')}'."
    p APP_BUNDLE_ID
    %x{/usr/local/bin/platypus -l -P #{APP_TEMPLATE.shellescape} #{APP_BUNDLE.shellescape}}
    fail "Error generating '#{bundle.pathmap('%f')}': `platypus` returned #{$?.exitstatus}." unless $?.exitstatus == 0
  }
end

Rake::OSX::BundleEditorTask.new(:app, APP_BUNDLE) do |t|
  t.description = 'Generate OS X Service provider application.'
  t.verbose     = true
  t.set_version = version.to_friendly
  t.set_build   = version.to_s

  supported_types = YAML.load_file(File.join(File.dirname(APP_TEMPLATE), "#{BASE_NAME}.utis.yaml")).values
  supported_utis  = supported_types.map {|e| e['UTTypeIdentifier'] }

  doc_type   = { # declare MutiMarkdown compatible document handling
    'LSItemContentTypes' => supported_utis,
    'CFBundleTypeRole'   => 'Viewer',
    'LSHandlerRank'      => 'None'
  }
  app_info   = { # Info.plist root
    'CFBundleDocumentTypes'      => [doc_type],          # override handled file types
    'UTImportedTypeDeclarations' => supported_types,     # import supported UTIs
    'LSMinimumSystemVersion'     => '10.9.0'             # minimum for system Ruby 2
  }
  ns_services = { # declare as Text service accepting compatible files
    'NSMenuItem'        => {'default' => FULL_NAME},
    'NSRequiredContext' => {'NSServiceCategory' => 'public.text'},
    'NSSendFileTypes'   => supported_utis,
    'NSSendTypes'       => ['NSStringPboardType']
  }

  t.edit_info = ->(data){
    data.merge!(app_info)
    data['NSServices'] = [data.fetch('NSServices', [{}])[0].merge(ns_services)]
    data
  }
end

# rake build
desc 'Build all packages.'
task :build => [:clobber, *PACKAGE_TASKS]

# rake zip
Rake::ZipTask.new(File.join(BUILD_DIR, "#{BASE_NAME}-packages-#{version}")) do |t|
  t.named_task = {zip: 'Zip all packages for upload to GitHub.'}
  t.verbose    = true
  t.files      = PACKAGES
  t.base       = PACKAGE_TASKS # depending on the files skips bundle editing
end

desc 'Test and build.'
task :default => [:test, :build]
