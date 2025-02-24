{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) attrNames;
  inherit (lib.lists) isList;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.nvim.lua) expToLua;
  inherit (lib.nvim.types) mkGrammarOption;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.types) either enum package listOf str;
  inherit (pkgs) elmPackages;

  cfg = config.vim.languages.elm;

  defaultServer = "elmls";
  servers = {
    elmls = {
      package = elmPackages.elm-language-server;
      lspConfig = ''
        lspconfig.elmls.setup{
          on_attach = default_on_attach,
          cmd = ${
          if isList cfg.lsp.package
          then expToLua cfg.lsp.package
          else ''{"${cfg.lsp.package}/bin/elm-language-server"}''
        },
          init_options = {
            elmReviewDiagnostics = 'warning',
            skipInstallPackageConfirmation = false,
            disableElmLSDiagnostics = false,
            onlyUpdateDiagnosticsOnSave = false,
          },
        };
      '';
    };
  };

  defaultFormat = "elm_format";
  formats = {
    elm_format = {
      package = elmPackages.elm-format;
      nullConfig = ''
        table.insert(
          ls_sources,
          null_ls.builtins.formatting.elm_format.with({
            command = "${cfg.format.package}/bin/elm-format",
          })
        )
      '';
    };
  };
in {
  _file = ./elm.nix;
  options.vim.languages.elm = {
    enable = mkEnableOption "Elm language support";

    treesitter = {
      enable = mkEnableOption "Elm treesitter" // {default = config.vim.languages.enableTreesitter;};
      package = mkGrammarOption pkgs "elm";
    };

    lsp = {
      enable = mkEnableOption "Elm LSP support" // {default = config.vim.languages.enableLSP;};

      server = mkOption {
        type = enum (attrNames servers);
        default = defaultServer;
        description = "Elm LSP server to use";
      };

      package = mkOption {
        type = either package (listOf str);
        default = servers.${cfg.lsp.server}.package;
        description = "Elm LSP server package, or the command to run as a list of strings";
        example = ''[ (lib.getExe pkgs.elmPackages.elm-language-server) "--debug" ]'';
      };
    };

    format = {
      enable = mkEnableOption "Elm formatter support" // {default = config.vim.languages.enableFormat;};
      type = mkOption {
        description = "Elm formatter to use";
        type = enum (attrNames formats);
        default = defaultFormat;
      };
      package = mkOption {
        description = "Elm formatter package";
        type = package;
        default = formats.${cfg.format.type}.package;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.treesitter.enable {
      vim.treesitter = {
        enable = true;
        grammars = [cfg.treesitter.package];
      };
    })

    (mkIf cfg.format.enable {
      vim.lsp.null-ls.enable = true;
      vim.lsp.null-ls.sources.elm_format = formats.${cfg.format.type}.nullConfig;
    })

    (mkIf cfg.lsp.enable {
      vim.lsp.lspconfig.enable = true;
      vim.lsp.lspconfig.sources.elmls = servers.${cfg.lsp.server}.lspConfig;
    })
  ]);
}
