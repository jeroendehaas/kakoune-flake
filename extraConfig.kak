# Taken from https://discuss.kakoune.com/t/atomic-commits-in-kakoune/1446/6

define-command git-hunk-stage %{
  git-hunk-apply-impl "--cached"
}

define-command git-hunk-unstage %{
  git-hunk-apply-impl "--cached --reverse"
}

define-command git-hunk-apply %{
  git-hunk-apply-impl ""
}

define-command git-hunk-reverse %{
  git-hunk-apply-impl "--reverse"
}

define-command -hidden git-hunk-apply-impl -params 1 %{ evaluate-commands -draft -save-regs ah| %{
  set-register a %arg{1}
  # Save the diff header to register h.
  execute-keys -draft '<space><a-/>^diff.*?\n(?=@@)<ret><a-x>"hy'
  # Select the current hunk.
  execute-keys ?^@@|^diff|^$<ret>K<a-x><semicolon><a-?>^@@<ret><a-x>
  set-register | %{
    ( printf %s "$kak_reg_h"; cat ) |
    git apply $kak_reg_a --whitespace=nowarn -
  } # NOTE: | register is used by default when no command is specified below
  execute-keys |<ret>
}}

define-command mgit -override -params .. %{
  evaluate-commands -save-regs ab %{
    set-register a %sh{ pwd }
    change-directory %sh{ dirname "${kak_buffile}" }

    git %arg{@}

    change-directory %reg{a}
  }
}

