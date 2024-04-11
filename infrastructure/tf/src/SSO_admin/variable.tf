variable "users" {
    default = {
      "naimot.oyewale" = {
        email      = "naimatoyewale@gmail.com"
        first_name = "Naimot"
        last_name  = "Oyewale"
      }
      "john.doe" = {
        email      = "john.doe@example.com"
        first_name = "John"
        last_name  = "Doe"
      }
      "jane.smith" = {
        email      = "jane.smith@example.com"
        first_name = "Jane"
        last_name  = "Smith"
      }
      # Add more users as needed
    }
  }
  
variable "groups" {
    default = {
      "admin-team" = {
        description = "Administrator Group"
      }
      "data-eng-team" = {
        description = "Data Engineering Team Group"
      }
      "marketing-team" = {
        description = "Marketing Team Group"
      }
      # Add more groups as needed
    }
  }
  
variable "permission_sets" {
    default = {
      "AdministratorAccess" = {
        name             = "AdministratorAccess"
        description      = "Administrator perm set"
        session_duration = "PT1H"
        managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
      }
      "Billing" = {
        name             = "Billing"
        description      = "Billing perm set"
        session_duration = "PT1H"
        managed_policy_arn = "arn:aws:iam::aws:policy/job-function/Billing"
      }
      "ReadOnlyAccess" = {
        name             = "ReadOnlyAccess"
        description      = "ReadOnlyAccess perm set"
        session_duration = "PT1H"
        managed_policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
      }
      "ViewOnlyAccess" = {
        name             = "ViewOnlyAccess"
        description      = "ViewOnlyAccess perm set"
        session_duration = "PT1H"
        managed_policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
      }
    }
  }

variable "PEOPLE_PROD" {
  description = "JSON data for people in the production environment."
}

variable "PEOPLE_STG" {
  description = "JSON data for people in the staging environment."
}

variable "PEOPLE_DEV" {
  description = "JSON data for people in the development environment."
}

variable "sso_admin_role_tags" {
  description = "Tags for the AWS SSO admin roles."
  type        = map(string)
  default     = {
    RoleWorkspace-0 = "stg"
    RoleWorkspace-1 = "dev"
    RoleWorkspace-2 = "prod"
  }
}

variable "region" {
    description = "AWS region to create resources in"
    type        = string
    default     = "us-east-1"
  }

# variable "permissions_list" {
#   type = list(object({
#     name = string
#     description = string
#     session_duration = string
#     managed_policies = list(string)
#     aws_accounts = list(string)
#     sso_groups = list(string)
#   }))
#   description = "List of permission set properties"
  
# }