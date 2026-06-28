namespace :translations do
  desc "Rebuild delivery artifacts for every published (namespace, locale)"
  task rebuild_artifacts: :environment do
    count = Translation::Artifact.rebuild_all
    puts "Rebuilt #{count} #{"artifact".pluralize(count)}."
  end
end
