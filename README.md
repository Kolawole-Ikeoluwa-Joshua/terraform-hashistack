# Terraform Hashistack

A Terraform-based deployment for the HashiStack, including a bastion host, Consul, HAProxy, Nginx, Nomad, & Traefik resources. This repository contains all necessary configurations and scripts to automate the setup and management of this robust infrastructure stack.

It covers setting up a consul cluster, running in AWS, which

- has sane defaults
- is relatively close to production-ready
- uses Terraform to persist your Infrastructure as Code
- requires minimal fuss and configuration
- is easy to adapt to your existing CI pipeline, if you have one

Here's our architecture:

```
( Your Laptop )
   |
(THE INTERNET)
   |
   |
[bastion] - [nginx]-(uses consul-template to render something from the consul KV store)
   /\
  /  \
 /    \
(consul) - (consul) - (consul) --> a 3-node consul cluster
   |
   |
(nomad) - (nomad) - (nomad) - a 3-node nomad cluster, acting as both servers and clients
```

I also ended up making a simple VPC config that creates a new VPC, a public and a private subnet, an internet gateway, and a routing table.

## Instructions

### AWS Setup

1. Create AWS Account, Log into AWS
2. Create + download a keypair named `keyPairName.pem` in AWS EC2
3. `cd $THIS_REPOSITORY/infrastructure`
4. `mkdir keys`
5. `chmod 600 ~/Downloads/keyPairName.pem && mv ~/Downloads/keyPairName.pem keys/`
6. In the AWS console, add an IAM user with programmatic access & administrator perms; save access key ID + secret key in keys/credentials.sh in the following format:

   export AWS_ACCESS_KEY_ID="yourawskeyid"
   export AWS_SECRET_ACCESS_KEY="yoursecretkey"

### Infrastructure Creation

1. `cd $THIS_REPOSITORY/infrastructure`
2. `source ./keys/credentials.sh` or define access_key = "access-key" & secret_key = "secret-key" in `terraform.tfvars` file.
3. `terraform init`
4. `terraform apply --target module.vpc`
5. `terraform apply`

_Note_: (When you're done working for the day, remember to `terraform destroy` your infrastructure to make sure AWS doesn't bill you for the time you're not using your infrastructure!)

### Log in to your instances

Remember that only instances in your public subnet are directly accessible from across the Internet. Bounce through the bastion host to get to hosts in your private subnet.

Use whatever key you created/downloaded for your terraform IAM user (above):

```
ssh-add infrastructure/keys/keyPairName.pem
ssh -A root@$BASTION_IP

# From your bastion or web server, jump to your non-publicly-accessible consul instances
# (enter this command from the first server you SSH into)
ssh $CONSUL_IP
```

### Locally accessing Consul and Nomad dashboards (UI)

This will forward ports from remote hosts through your bastion host onto your local (work) machine. You can then access the consul and nomad UIs as if you were running a local binary.

1. Look up your bastion, consul, and nomad hosts' IPs (just one consul and nomad IP is fine):

```
    export BASTION_HOST=1.2.3.4
    export CONSUL_SERVER=4.5.6.7
    export NOMAD_SERVER=6.7.8.9
```

2. Use ssh local forwarding to map those services' UI ports to your local machine

```
ssh -A ubuntu@$BASTION_HOST -L 8500:$CONSUL_SERVER:8500 -L 4646:$NOMAD_SERVER:4646
```

3. Now you can access those UIs locally!

- Nomad http://localhost:4646/ui/jobs
- Consul http://localhost:8500/ui/vtl-linux/services

### Run etherpad service on nomad

1. ssh to a nomad server (via bastion)

   nomad run /etc/nomad.d/etherpad.jobspec

2. watch the deployment on the nomad UI or via `nomad status etherpad`


### Additional Documentation (FAQS)

- [Architecture Breakdown]()

### Common troubleshooting tasks

`Error: error configuring Terraform AWS Provider: no valid credential sources for Terraform AWS Provider found.`
This means you forgot to use the credentials.sh script before starting to work in a new shell session.

See more verbose terraform output in your shell:
`export TF_LOG=DEBUG`

Cloud-init scripts not running? Have a look at the cloud-init log, or tail (-f follow) it:
`less /var/log/cloud-init-output.log`
`journalctl -u cloud-init`
`journalctl -fu cloud-init`

If you get lost troubleshooting, check what your cloud-init script actually looks like when it's rendered on your instance as user-data: - cat /var/lib/cloud/instance/user-data.txt

Consul:
`systemctl status consul`
`journalctl -fu consul`

Nomad:
`systemctl status nomad`
`journalctl -fu nomad`

### Official Resources

https://learn.hashicorp.com/consul?track=advanced#operations-and-development
