{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.peon-ping;
  jsonFormat = pkgs.formats.json { };

  ogPacksVersion = "1.4.0";

  # Fetch the og-packs repository
  ogPacksSrc = pkgs.fetchzip {
    url = "https://github.com/PeonPing/og-packs/archive/refs/tags/v${ogPacksVersion}.tar.gz";
    sha256 = "sha256-jkybxNrXfc8GFPAi0Lb1rF8fsx8Z8K0k5gQxh8Y62Ds=";
    stripRoot = false;
  };
in
{
  options.programs.peon-ping = {
    enable = mkEnableOption "peon-ping — Warcraft III Peon voice lines for Claude Code hooks";

    package = mkOption {
      type = types.package;
      default = pkgs.peon-ping or (throw "peon-ping not available in nixpkgs. Use the flake package instead.");
      defaultText = literalExpression "pkgs.peon-ping";
      description = "The peon-ping package to use.";
    };

    settings = mkOption {
      type = jsonFormat.type;
      default = { };
      description = ''
        peon-ping configuration written to ~/.openpeon/config.json.
        See https://github.com/PeonPing/peon-ping for all options.
      '';
      example = literalExpression ''
        {
          default_pack = "peon";
          volume = 0.5;
          enabled = true;
          desktop_notifications = true;
          categories = {
            "session.start" = true;
            "task.complete" = true;
            "task.error" = true;
            "input.required" = true;
            "resource.limit" = true;
            "user.spam" = true;
            "task.acknowledge" = false;
          };
          pack_rotation = [ ];
          pack_rotation_mode = "random";
          annoyed_threshold = 3;
          annoyed_window_seconds = 10;
          silent_window_seconds = 0;
          suppress_subagent_complete = false;
          use_sound_effects_device = true;
        }
      '';
    };

    installPacks = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of sound pack names to install automatically - fetched from the og-packs repository.
        Common packs: peon, glados, sc_kerrigan, murloc, witcher
      '';
      example = literalExpression ''[ "peon" "glados" ]'';
    };

    enableZshIntegration = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable Zsh completions and alias.
      '';
    };

    enableBashIntegration = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable Bash completions and alias.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Install base files from share into ~/.openpeon, excluding peon.sh which is wrapped by bin/peon.sh
    home.file.".openpeon" = {
      source = pkgs.runCommand "peon-home-files" {} ''
        cp -r ${cfg.package}/share/peon-ping $out
        chmod -R u+w $out
        rm -f $out/peon.sh
      '';
      recursive = true;
    };

    # PEON_DIR points at ~/.openpeon where all runtime files live.
    home.sessionVariables.PEON_DIR = "${config.home.homeDirectory}/.openpeon";

    # peon.sh in ~/.openpeon is the bin/peon wrapper (has runtime PATH baked in).
    home.file.".openpeon/peon.sh".source = "${cfg.package}/bin/peon";

    # Create the config file at the location peon-ping expects.
    # Overrides any config.json that may be present in the package.
    home.file.".openpeon/config.json".source = jsonFormat.generate "peon-ping-config" cfg.settings;

    # Install sound packs directly from og-packs repository
    home.file.".openpeon/packs" = lib.mkIf (cfg.installPacks != [ ]) {
      source = pkgs.runCommand "peon-packs" { } ''
        set -euo pipefail
        mkdir -p $out
        ${lib.concatMapStringsSep "\n" (packName: ''
          if [ -d "${ogPacksSrc}/og-packs-${ogPacksVersion}/${packName}" ]; then
            cp -r "${ogPacksSrc}/og-packs-${ogPacksVersion}/${packName}" $out/
          else
            echo "Error: Pack '${packName}' not found in og-packs" >&2
            exit 1
          fi
        '') cfg.installPacks}
      '';
    };

    # Shell completions
    programs.zsh.initExtra = mkIf cfg.enableZshIntegration ''
      source ${cfg.package}/share/zsh/site-functions/_peon 2>/dev/null || true
      alias peon="${cfg.package}/bin/peon"
    '';

    programs.bash.initExtra = mkIf cfg.enableBashIntegration ''
      source ${cfg.package}/share/bash-completion/completions/peon 2>/dev/null || true
      alias peon="${cfg.package}/bin/peon"
    '';
  };
}
