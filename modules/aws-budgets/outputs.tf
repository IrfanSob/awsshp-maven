output "budget_ids" {
  description = "Map of budget keys to their IDs"
  value = {
    for k, v in aws_budgets_budget.this : k => v.id
  }
}

output "budget_arns" {
  description = "Map of budget keys to their ARNs"
  value = {
    for k, v in aws_budgets_budget.this : k => v.arn
  }
}

output "budget_names" {
  description = "Map of budget keys to their names"
  value = {
    for k, v in aws_budgets_budget.this : k => v.name
  }
}
