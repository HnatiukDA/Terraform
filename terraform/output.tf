output "private_ip" {
  value = zipmap(aws_instance.instance.*.tags.Name, aws_instance.instance.*.private_ip)
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = zipmap(aws_instance.instance.*.tags.Name, aws_instance.instance.*.public_ip)
}

output "alb_public_ip" {
  value = aws_lb.alb.dns_name
}

output "public_ip" {
  value = zipmap(aws_instance.instance.*.tags.Name, aws_eip.eip.*.public_ip)
}

output "public_dns" {
  value = zipmap(aws_instance.instance.*.tags.Name, aws_eip.eip.*.public_dns)
}

output "private_dns" {
  value = zipmap(aws_instance.instance.*.tags.Name, aws_instance.instance.*.private_dns)
}
