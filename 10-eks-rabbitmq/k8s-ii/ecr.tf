module "ecr" {
  source          = "terraform-aws-modules/lambda/aws//modules/docker-build"
  create_ecr_repo = true
  ecr_repo        = "latency-calc"
  source_path     = "${path.module}/../src"
  platform        = "linux/amd64"

  image_tag = sha1(join("", [
    filesha1("${path.module}/../src/calc.py"),
    filesha1("${path.module}/../src/requirements.txt"),
    filesha1("${path.module}/../src/Dockerfile"),
  ]))

  ecr_repo_lifecycle_policy = jsonencode({
    "rules" : [
      {
        "rulePriority" : 1,
        "description" : "Keep only the last 1 image",
        "selection" : {
          "tagStatus" : "any",
          "countType" : "imageCountMoreThan",
          "countNumber" : 1
        },
        "action" : {
          "type" : "expire"
        }
      }
    ]
  })
}
