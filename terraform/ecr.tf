resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}/task-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true # free basic vulnerability scanning - ties into Phase 6
  }
}

# Keep only the 5 most recent images, so repeated pushes during
# development can never accidentally exceed the ECR free-tier storage.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire all but the 5 most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}