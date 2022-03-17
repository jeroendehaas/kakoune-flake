{ lib, config, pkgs, ... }:
with lib;
let
  user-mode = { name, key, docstring, outermode ? "user"}: mappings:
    [{ inherit docstring key; mode = outermode; effect = ": enter-user-mode ${name}<ret>"; } ]
      ++ builtins.map (m: m // {mode = name;}) mappings;
  winSetOption = filetypes: commands:
    let ftOpt = lib.concatStringsSep "|" filetypes;
    in {
      name="WinSetOption";
      option = "filetype=(" + ftOpt + ")";
      commands = commands;
    };
  indentwidth = width: filetypes: (winSetOption filetypes ''
    set-option window indentwidth ${builtins.toString width}
  '');
  cfg = config.qqlq.kakoune;
in {
  options = {
    qqlq.kakoune = with types; {
      lsp = mkOption {
        type = submodule {
          options = {
            enable = mkEnableOption "Enable kak-lsp";
            filetypes = mkOption {
              type = listOf str;
              default = [];
              example = ["idris" "cpp"];
            };
          };
        };
      };
      colorscheme = mkOption {
        type = either str (submodule { options = {
                            dark = mkOption {
                              type = str;
                              example = "solarized-dark";
                            };
                            light = mkOption {
                              type = str;
                              example = "solarized-light";
                            };
                            fallback = mkOption {
                              type = str;
                              example = "solarized-dark";
                            };
                            extraColorschemes = mkOption {
                              type = listOf package;
                            };
                          };});
        default = null;
        example = "solarized-dark";
      };
      lightColorscheme = mkOption {
        type = nullOr str;
        default = null;
        example = "solarized-light";
      };
    };
  };

  config = {
    xdg = lib.mkIf ((builtins.length cfg.colorscheme.extraColorschemes) > 0) {
      configFile."kak/colors".source = pkgs.symlinkJoin {
        name = "kak-colors";
        paths = cfg.colorscheme.extraColorschemes;
      };
    };
    programs.kakoune = {
      enable = true;
      plugins =
        (with pkgs.kakounePlugins; [
          kak-fzf
          kakoune-mirror
          kakoune-idris2
          kakoune-rainbow
          connect-kak # required for kakoune-rainbow
          prelude-kak # required for connect-kak
          kakoune-kaktree
        ])
        #++ (with pkgs.extraKakounePlugins; [ kakoune-mirror kakoune-dracula kakoune-one kakoune-idris2 ])
        ++ (optional cfg.lsp.enable pkgs.kakounePlugins.kak-lsp);
      extraConfig =
        let
          toml = pkgs.writeTextFile { name = "kak-lsp.toml"; text = (builtins.readFile ./kak-lsp.toml); };
          fixColorscheme =
            if builtins.isString cfg.colorscheme
            then ''printf '%s' "${cfg.colorscheme}"''
            else ''
                  if ! command -v defaults > /dev/null; then
                    printf '%s' "${cfg.colorscheme.fallback}"
                  elif defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
                    printf '%s' "${cfg.colorscheme.dark}"
                  else
                    printf '%s' "${cfg.colorscheme.light}"
                  fi
            '';
        in ''
          ${optionalString cfg.lsp.enable "eval %sh{${pkgs.kak-lsp}/bin/kak-lsp --kakoune -s $kak_session -c ${toml} -vvv --log $HOME/kak-lsp.log}"}
          define-command -docstring "Set appropriate color scheme for interface style" \
            fix-colorscheme %{
              colorscheme %sh{
                  ${fixColorscheme}
              }
            }
          fix-colorscheme

          require-module rainbow
          kaktree-enable
        '' + (builtins.readFile ./extraConfig.kak);
      config = {
        hooks = [
          (indentwidth 2 ["cpp" "c" "latex" "markdown" "nix" "css" "html" "javascript" "haskell" "idris"])
          (indentwidth 4 ["python"])
          {
            name = "InsertChar";
            option = "\\t";
            commands = ''
              try %{
                execute-keys -draft "h<a-h><a-k>\A\h+\z<ret><a-;>;%opt{indentwidth}@"
              }
            '';
          }
          (winSetOption ["latex" "markdown"] ''
            add-highlighter window/ wrap -word -indent -width 78 -marker '^   '
            set-option window lintcmd '${pkgs.proselint}/bin/proselint'
            hook -group my-markdown-hooks window BufWritePost .* %{
              spell
            }
          '')
          (winSetOption ["html"] ''
              set-option buffer formatcmd "${pkgs.html-tidy}/bin/tidy"
          '')
          (winSetOption ["idris"] ''
            add-highlighter window/ number-lines -min-digits 4
            hook window InsertChar \n -group my-idris-indent idris-newline
            hook window InsertDelete ' ' -group my-idris-indent idris-delete
            hook -once -always window WinSetOption filetype=.* %{ remove-hooks window my-idris2-.* }
          '')
          (winSetOption ["latex" "cpp" "c"] ''
            add-highlighter window/ number-lines -min-digits 4
          '')
          (winSetOption cfg.lsp.filetypes ''
            lsp-enable-window
            lsp-auto-hover-enable
          '')
          (winSetOption ["kaktree"] ''
            remove-highlighter buffer/numbers
            remove-highlighter buffer/matching
            remove-highlighter buffer/wrap
            remove-highlighter buffer/show-whitespaces
          '')
        ];
        keyMappings = lib.flatten [
          (user-mode { name = "file-um"; key = "f"; docstring = "File..."; } [
            { key = "f"; effect=":e "; docstring ="Edit file"; }
            { key = "F"; effect='':exec %sh{ printf ": e $(dirname $kak_buffile)/" }<ret>''; docstring="Edit file (PWD)"; }
          ])
          (user-mode { name = "buffer-um"; key = "b"; docstring = "Buffer..."; } [
            { key = "s"; effect=":w<ret>"; docstring ="Save"; }
            { key = "n"; effect=":buffer-next<ret>"; docstring="Next"; }
            { key = "p"; effect=":buffer-previous<ret>"; docstring="Previous"; }
            { key = "b"; effect=":buffer "; docstring="Switch"; }
            { key = "d"; effect=":delete-buffer<ret>"; docstring="Delete"; }
          ])
          (user-mode { name = "spell-um"; key = "s"; docstring = "Spell..."; } [
            { key = "s"; effect="<a-i>w: spell-replace<ret>"; docstring ="Replace"; }
            { key = "c"; effect=":spell<ret>"; docstring="Check"; }
            { key = "n"; effect=":spell-next<ret>"; docstring="Next"; }
            { key = "a"; effect=":spell-add<ret>"; docstring="Learn word"; }
          ])
          (user-mode { outermode="normal"; name = "select-um"; key = "v"; docstring = "Select..."; } [
            { key = "a"; effect="<a-a>"; docstring ="Around"; }
            { key = "A"; effect="<a-A>"; docstring ="Around (extend)"; }
            { key = "i"; effect="<a-i>"; docstring="Inside"; }
            { key = "I"; effect="<a-I>"; docstring="Inside (extend)"; }
            { key = "f"; effect="<a-f>"; docstring="Backwards find"; }
            { key = "F"; effect="<a-f>"; docstring="Backwards find (extend)"; }
            { key = "t"; effect="<a-t>"; docstring="Backwards to"; }
            { key = "T"; effect="<a-t>"; docstring="Backwards to (extend)"; }
            { key = "/"; effect="<a-/>"; docstring="Backwards search"; }
            { key = "?"; effect="<a-?>"; docstring="Backwards search (extend)"; }
          ])
          (user-mode { name = "window-um"; key = "w"; docstring = "Window..."; } [
            { key = "h"; effect=":tmux-repl-horizontal"; docstring ="Split horizontal"; }
            { key = "v"; effect=":tmux-repl-vertical<ret>v"; docstring="Split vertical"; }
            { key = "f"; effect=":new e "; docstring="Open in new"; }
          ])
          (user-mode { name = "git-um"; key = "g"; docstring="Git..."; } [
            { key = "a"; effect=":mgit add<ret>"; docstring = "Add"; }
            { key = "c"; effect=":mgit commit<ret>"; docstring = "Commit"; }
            { key = "C"; effect=":mgit commit --amend<ret>"; docstring = "Amend"; }
            { key = "l"; effect=":mgit log<ret>"; docstring = "Log"; }
            { key = "d"; effect=":mgit diff<ret>"; docstring = "Diff"; }
            { key = "s"; effect=":mgit status<ret>"; docstring = "Status"; }
          ])
          (user-mode { name = "open-um"; key = "o"; docstring = "Open..."; } [
            { key = "t"; effect=": tmux-terminal-vertical %sh{ echo $SHELL }"; docstring = "Terminal"; }
          ])
          { docstring = "leader key"; effect = ","; key = "<space>"; mode = "normal"; }
          { docstring = "FZF"; effect =": fzf-mode<ret>"; key = "p"; mode = "user"; }
          { docstring = "single selection"; effect = "<space>"; key = "<backspace>"; mode = "normal"; }
          { docstring = "LSP..."; key = "l"; mode = "user"; effect = ": enter-user-mode lsp<ret>"; }
          { docstring = "Rainbow on"; key = "r"; mode = "user"; effect = ": rainbow<ret>"; }
          { docstring = "Rainbow off"; key = "R"; mode = "user"; effect = ": rmhl window/ranges_rainbow_specs<ret>"; }
          { mode = "normal"; key = "\"'\""; effect=": enter-user-mode -lock mirror<ret>"; }
          { mode = "user"; key = "v"; effect="v"; docstring="View..."; }
          { mode = "user"; key = "V"; effect="V"; docstring="View (lock)..."; }
        ] ++ (lib.optionals pkgs.stdenv.isDarwin [
          { mode = "normal"; key = "y"; effect="<a-|>pbcopy<ret>y"; }
        ]);
      };
    };
  };
}
