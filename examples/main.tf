module "prometheus" {
    source = "./module"
    instance_type_prometheus = "t3.medium"
    volume_size_prometheus = "30"
    key_name = "nw-prometheus"
    environment = "qa"
    vpc_cidr_block = ""
    vpc_id = ""
}