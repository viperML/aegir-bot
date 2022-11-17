job "aegir-bot" {
  datacenters = ["dc1"]

  type = "batch"

  periodic {
    cron             = "00 9 * * *"
    prohibit_overlap = true
    time_zone        = "Europe/Berlin"
  }

  group "main-group" {
    count = 1

    restart {
      attempts = 0
    }

    network {
      mode = "bridge"
      dns {
        servers = [
          "8.8.8.8",
          "8.8.4.4"
        ]
        options = [
          "edns0",
          "trust-ad"
        ]
      }
    }

    task "run" {
      driver = "docker"
      restart {
        attempts = 0
      }

      vault {
        policies = ["aegir-bot"]
      }

      template {
        data        = <<EOF
          DANBOORU_USERNAME="{{with secret "kv/data/aegir-bot"}}{{.Data.data.DANBOORU_USERNAME}}{{end}}"
          DANBOORU_APIKEY="{{with secret "kv/data/aegir-bot"}}{{.Data.data.DANBOORU_APIKEY}}{{end}}"
          AEGIR_ENV_PATH=secrets/aegir_env.toml
        EOF
        env         = true
        destination = "secrets/login.env"
      }

      template {
        data = <<EOF
          {{with secret "kv/data/aegir-bot"}}{{.Data.data.AEGIR_ENV}}{{end}}
        EOF
        destination = "secrets/aegir_env.toml"
      }

      config {
        nix_flake_ref = "github:viperML/aegir-bot/${var.rev}#default"
        nix_flake_sha = var.narHash
        entrypoint = [
          "bin/aegir-bot",
        ]
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}

variable "rev" {
  type = string
  validation {
    condition     = var.rev != "null"
    error_message = "Git tree is dirty."
  }
}

variable "narHash" {
  type = string
}
