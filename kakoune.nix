{ lib, config, pkgs, ... }:
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
  kak-lsp-toml = import ./kak-lsp.nix { inherit config pkgs; };
in {

  programs.kakoune = {
    enable = true;
    plugins = (with pkgs.kakounePlugins; [
      kak-lsp
      kak-fzf
    ]) ++ (with pkgs.extraKakounePlugins; [ kakoune-mirror kakoune-dracula kakoune-one   ]);
    extraConfig = ''
      eval %sh{${pkgs.kak-lsp}/bin/kak-lsp --kakoune -s $kak_session -c ${kak-lsp-toml}}

      define-command -docstring "Set appropriate color scheme for interface style" \
        fix-colorscheme %{
          evaluate-commands %sh{
              if command -v defaults >/dev/null; then
                if defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
                    printf 'source %s' "${pkgs.extraKakounePlugins.kakoune-dracula}/share/kak/autoload/plugins/kakoune-dracula/colors/dracula.kak"
                else
                    printf 'source %s' "${pkgs.extraKakounePlugins.kakoune-one}/share/kak/autoload/plugins/kakoune-one/colors/one-light.kak"
                fi
              fi
          }
        }
      fix-colorscheme

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
            set-option buffer formatcmd "${pkgs.htmlTidy}/bin/tidy"
        '')
        (winSetOption ["latex" "cpp" "c"] ''
          lsp-enable-window
          add-highlighter window/ number-lines -min-digits 4
          lsp-auto-hover-enable
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
          { key = "l"; effect=":mgit log<ret>"; docstring = "Log"; }
          { key = "d"; effect=":mgit diff<ret>"; docstring = "Diff"; }
          { key = "s"; effect=":mgit status<ret>"; docstring = "Status"; }
        ])
        { docstring = "leader key"; effect = ","; key = "<space>"; mode = "normal"; }
        { docstring = "FZF"; effect = ": fzf-mode<ret>"; key = "<c-p>"; mode = "normal"; }
        { docstring = "single selection"; effect = "<space>"; key = "<backspace>"; mode = "normal"; }
        { docstring = "LSP..."; key = "l"; mode = "user"; effect = ": enter-user-mode lsp<ret>"; }
        { mode = "normal"; key = "\"'\""; effect=": enter-user-mode -lock mirror<ret>"; }
        { mode = "user"; key = "v"; effect="v"; docstring="View..."; }
        { mode = "user"; key = "V"; effect="V"; docstring="View (lock)..."; }
      ];
    };
  };
}
