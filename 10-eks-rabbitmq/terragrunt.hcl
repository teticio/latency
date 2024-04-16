dependency "module" {
  config_path = "k8s-ii"
}

inputs = {
  url = dependency.module.outputs.url
}
