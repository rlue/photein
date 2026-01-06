project := "photein"
version := `ruby -r ./lib/photein/version.rb -e 'puts Photein::VERSION'`
next_version := shell("printf '%s\n' " + quote(version) + " | awk -F. '{ $3++; print $1\".\"$2\".\"$3 }'")

# Increment the patch version number and push
bump:
  perl -pi -e 's/\Q{{version}}\E/{{next_version}}/' lib/{{project}}/version.rb
  perl -pi -e 's/\Q{{project}} ({{version}})\E/{{project}} ({{next_version}})/' Gemfile.lock
  git add lib/{{project}}/version.rb Gemfile.lock
  git commit -m "rel: Bump to v{{next_version}}"
  for remote in $(git remote); do git push $remote; done

# Build and publish to RubyGems and Docker Hub
publish:
  gem build {{project}}.gemspec
  gem push {{project}}-{{version}}.gem
  docker buildx build --build-arg VERSION="{{version}}" --platform linux/amd64,linux/arm64 -t rlue/{{project}}:latest -t rlue/{{project}}:{{version}} --builder container --push .
