require 'bundler'
Bundler::GemHelper.install_tasks

HOME  = ENV["HOME"]
PBDIR = HOME+"/src/doozer/src/pkg/proto"

namespace :proto do
  task :update do
    ENV["BEEFCAKE_NAMESPACE"] = "Fraggle"
    sh(
      "protoc",
      "--beefcake_out", "lib/fraggle",
      "-I",  PBDIR,
      PBDIR+"/msg.proto"
    )
  end
end
