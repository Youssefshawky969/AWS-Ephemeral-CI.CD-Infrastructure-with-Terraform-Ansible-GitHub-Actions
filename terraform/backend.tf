terraform {
  cloud {
    organization = "aws_pipelines"

    workspaces {
      name = "aws_dev"
    }
  }
}
