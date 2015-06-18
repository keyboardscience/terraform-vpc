///////////////////////
// provider resource
///////////////////////

provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws_region}"
}

///////////////////////
// vpc resources
///////////////////////

resource "aws_vpc" "primary" {
    instance_tenancy = "dedicated"
    cidr_block = "${lookup(var.vpc_networks,var.aws_region)}.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags {
        Name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-${var.aws_region}"
    }
}

output "datacenter_id" {
    value = "${aws_vpc.primary.id}"
}

output "datacenter_network" {
    value = "${aws_vpc.primary.cidr_block}"
}

resource "aws_internet_gateway" "igw" {
    vpc_id = "${aws_vpc.primary.id}"
}

///////////////////////
// subnet resources
///////////////////////

// DMZ

resource "aws_subnet" "dmzA" {
    vpc_id = "${aws_vpc.primary.id}"
    availability_zone = "${var.aws_region}a"
    cidr_block = "${lookup(var.vpc_networks,var.aws_region)}.0.0/24"
    map_public_ip_on_launch = "true"
    tags {
        Name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-subnet-dmzA"
    }
}

output "datacenter_subnet_dmzA_id" {
    value = "${aws_subnet.dmzA.id}"
}

resource "aws_route_table_association" "dmzA-dmz" {
    subnet_id = "${aws_subnet.dmzA.id}"
    route_table_id = "${aws_route_table.dmz.id}"
}

resource "aws_subnet" "dmzB" {
    vpc_id = "${aws_vpc.primary.id}"
    availability_zone = "${var.aws_region}b"
    cidr_block = "${lookup(var.vpc_networks,var.aws_region)}.1.0/24"
    map_public_ip_on_launch = "true"
    tags {
        Name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-subnet-dmzB"
    }
}

output "datacenter_subnet_dmzB_id" {
    value = "${aws_subnet.dmzB.id}"
}

resource "aws_route_table_association" "dmzB-dmz" {
    subnet_id = "${aws_subnet.dmzB.id}"
    route_table_id = "${aws_route_table.dmz.id}"
}

// NAT

resource "aws_subnet" "natA" {
    vpc_id = "${aws_vpc.primary.id}"
    availability_zone = "${var.aws_region}a"
    cidr_block = "${lookup(var.vpc_networks,var.aws_region)}.128.0/24"
    map_public_ip_on_launch = "false"
    tags {
        Name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-subnet-natA"
    }
}

output "datacenter_subnet_natA_id" {
    value = "${aws_subnet.natA.id}"
}

resource "aws_route_table_association" "natA-nat" {
    subnet_id = "${aws_subnet.natA.id}"
    route_table_id = "${aws_route_table.nat.id}"
}

resource "aws_subnet" "natB" {
    vpc_id = "${aws_vpc.primary.id}"
    availability_zone = "${var.aws_region}b"
    cidr_block = "${lookup(var.vpc_networks,var.aws_region)}.129.0/24"
    map_public_ip_on_launch = "false"
    tags {
        Name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-subnet-natB"
    }
}

output "datacenter_subnet_natB_id" {
    value = "${aws_subnet.natB.id}"
}

resource "aws_route_table_association" "natB-nat" {
    subnet_id = "${aws_subnet.natB.id}"
    route_table_id = "${aws_route_table.nat.id}"
}

// Security Groups
resource "aws_security_group" "cachec" {
    name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-CACHE-Clients"
    description = "Whitelist Redis (tcp 6379)"
    vpc_id = "${aws_vpc.primary.id}"
}

output "cache_client_sg" {
    value = "${aws_security_group.cachec.id}"
}

resource "aws_security_group" "cache" {
    name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-CACHE"
    description = "Allow Redis (tcp 6379)"
    vpc_id = "${aws_vpc.primary.id}"

    ingress {
        from_port = 6379
        to_port = 6379
        protocol = "tcp"
        self = "true"
        security_groups = ["${aws_security_group.cachec.id}"]
    }
}

output "cache_sg" {
    value = "${aws_security_group.cache.id}"
}

resource "aws_security_group" "searchc" {
    name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-SEARCH-Clients"
    description = "Whitelist Elasticsearch (tcp 9200)"
    vpc_id = "${aws_vpc.primary.id}"
}

output "search_client_sg" {
    value = "${aws_security_group.searchc.id}"
}

resource "aws_security_group" "search" {
    name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-SEARCH"
    description = "Allow Elasticsearch (tcp 9200)"
    vpc_id = "${aws_vpc.primary.id}"

    // Client Access

    ingress {
        from_port = 9200
        to_port = 9200
        protocol = "tcp"
        self = "true"
        security_groups = ["${aws_security_group.searchc.id}"]
    }

    ingress {
        from_port = 9300
        to_port = 9300
        protocol = "tcp"
        self = "true"
        security_groups = ["${aws_security_group.searchc.id}"]
    }

    // Cluster communication
    //      Allow the client SG to simplify the bootstrap

    ingress {
        from_port = 9400
        to_port = 9400
        protocol = "tcp"
        self = "true"
        security_groups = ["${aws_security_group.searchc.id}"]
    }

    ingress {
        from_port = 9500
        to_port = 9500
        protocol = "tcp"
        self = "true"
        security_groups = ["${aws_security_group.searchc.id}"]
    }
}

output "search_sg" {
    value = "${aws_security_group.search.id}"
}

resource "aws_security_group" "web" {
    name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-WEB"
    description = "Allow HTTP and HTTPS from Any"
    vpc_id = "${aws_vpc.primary.id}"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

output "web_sg" {
    value = "${aws_security_group.web.id}"
}

resource "aws_security_group" "ssh" {
    name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-SSH"
    description = "Allow SSH"
    vpc_id = "${aws_vpc.primary.id}"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["142.254.16.146/32","${lookup(var.vpc_networks,var.aws_region)}.0.0/16","23.121.240.216/32"]
    }
}

output "ssh_sg" {
    value = "${aws_security_group.ssh.id}"
}

resource "aws_security_group" "sshc" {
    name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-SSH-Clients"
    description = "Whitelist SSH Clients"
    vpc_id = "${aws_vpc.primary.id}"
}

output "ssh_client_sg" {
    value = "${aws_security_group.sshc.id}"
}

resource "aws_security_group" "db" {
    name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-DB"
    description = "Allow Postgres"
    vpc_id = "${aws_vpc.primary.id}"

    ingress {
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        self = "true"
        security_groups = ["${aws_security_group.dbc.id}"]
    }
}

output "db_sg" {
    value = "${aws_security_group.db.id}"
}

resource "aws_security_group" "dbc" {
    name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-DB-Clients"
    description = "Whitelist Postgres Clients"
    vpc_id = "${aws_vpc.primary.id}"
}

output "db_client_sg" {
    value = "${aws_security_group.dbc.id}"
}

///////////////////////
// nat resources
///////////////////////

// Security Group

resource "aws_security_group" "natc" {
    name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-NAT-Clients"
    description = "Used to whitelist clients to NAT host"
    vpc_id = "${aws_vpc.primary.id}"
}

output "datacenter_nat_subnet_default_security_group_id" {
    value = "${aws_security_group.natc.id}"
}

resource "aws_security_group" "nat" {
    name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-NAT"
    description = "Allow any HTTP, HTTPS and ICMP."
    vpc_id = "${aws_vpc.primary.id}"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["142.154.16.146/32"]
    }
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = ["${aws_security_group.natc.id}"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        security_groups = ["${aws_security_group.natc.id}"]
    }
    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        security_groups = ["${aws_security_group.natc.id}"]
    }
}

// Instance

resource "aws_instance" "nat" {
    ami = "${lookup(var.aws_nat_amis,var.aws_region)}"
    instance_type = "m3.medium"
    key_name = "${var.aws_key_name}"
    security_groups = [ "${aws_security_group.nat.id}" ]
    subnet_id = "${aws_subnet.dmzA.id}"
    source_dest_check = false
    tags {
        Name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-nat"
    }
}

resource "aws_eip" "nat" {
    instance = "${aws_instance.nat.id}"
    vpc = true
}

///////////////////////
// Networking resources
///////////////////////

resource "aws_route_table" "dmz" {
    vpc_id = "${aws_vpc.primary.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.igw.id}"
    }
    tags {
        Name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-dmz-rtb"
    }
}

resource "aws_route_table" "nat" {
    vpc_id = "${aws_vpc.primary.id}"
    route {
        cidr_block = "0.0.0.0/0"
        instance_id = "${aws_instance.nat.id}"
    }
    tags {
        Name = "vpc-${lookup(var.vpc_networks,var.aws_region)}-nat-rtb"
    }
}