output "prestashop_public_ip" {
  value = aws_instance.prestashop.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

# Output the PrestaShop URL
output "prestashop_url" {
  value = "http://${aws_instance.prestashop.public_ip}"
}
