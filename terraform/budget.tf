# Free safety net: emails you if account spend crosses 80% or 100% of
# $7 in a month. Doesn't prevent spend, just makes sure you find out fast.
resource "aws_budgets_budget" "monthly_cost_guard" {
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = "7"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}