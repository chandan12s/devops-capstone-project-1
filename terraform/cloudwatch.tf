# CloudWatch's always-free tier covers 5GB of log ingestion/storage,
# 10 custom metrics, and 10 alarms per month - we're nowhere near that
# for this project, but we set a short retention anyway as good hygiene
# (logs with no expiry are a classic source of slow, silent cost creep).

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/app"
  retention_in_days = 7
}
