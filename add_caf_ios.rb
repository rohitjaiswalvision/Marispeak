require 'xcodeproj'
project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('Runner', true)
file_ref = group.new_reference('marispeak_ringtone.caf')

resources_build_phase = target.resources_build_phase
resources_build_phase.add_file_reference(file_ref)

project.save
