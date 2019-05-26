# outputs.tf

output "instances_dns" {
  value = "${aws_instance.testfront.*.public_dns}"
}

output "testapp_dns" {
  value = "${aws_elb.testapp.dns_name}"
}

output "db_instance_endpoint" {
  value = "${aws_db_instance.default.endpoint}"
}
