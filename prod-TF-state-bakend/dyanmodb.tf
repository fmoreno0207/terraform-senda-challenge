resource "aws_dynamodb_table" "terraform_locks" {
    name = "${var.environment_name}-tf-state-dynamo-table"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID"
    attribute {
        name = "LockID"
        type = "S"
    }
}