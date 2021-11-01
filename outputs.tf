output "base_url" {
  value = aws_api_gateway_stage.gw_stage.invoke_url
}