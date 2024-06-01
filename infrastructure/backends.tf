terraform {
  backend "remote" {
    organization = "vtl-terraform"

    workspaces {
      name = "vtl-hashistack"
    }
  }
}