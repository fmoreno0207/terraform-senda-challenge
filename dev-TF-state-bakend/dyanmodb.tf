resource "aws_dynamodb_table" "terraform_locks" {
    name = "${var.project}-${var.environment_name}-tf-state-dynamo-db-table"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID"
    attribute {
        name = "LockID"
        type = "S"
    }
}