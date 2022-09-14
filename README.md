```
        ┏━━━┓
        ┃┏━┓┃
┏┓┏┳┳━┓┏┫┗━━┳━┓┏┳━━┓
┃┗┛┣┫┏┓╋╋━━┓┃┏┓╋┫┏┓┃
┃┃┃┃┃┃┃┃┃┗━┛┃┃┃┃┃┗┛┃
┗┻┻┻┻┛┗┻┻━━━┻┛┗┻┫┏━┛
                ┃┃
                ┗┛
```

**miniSnip** is lightweight and minimal snippet plugin written in Vim Script.

## Installation

Use your favourite plugin manager to install miniSnip:

#### [minPlug](https://github.com/Jorengarenar/minPlug):
```vim
MinPlug Jorengarenar/miniSnip
```

#### [vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'Jorengarenar/miniSnip'
```

#### Vim's packages
```bash
cd ~/.vim/pack/plugins/start
git clone git://github.com/Jorengarenar/miniSnip.git
```

#### [NeoBundle](https://github.com/Shougo/neobundle.vim)
```vim
NeoBundle 'Jorengarenar/miniSnip'
```

## Usage

To get started with miniSnip, in your runtime (on UNIX usually: `~/.vim`)
create a directory called `miniSnip/all`. Then placing a file called `foo.snip`
inside it will create the `foo` snippet, which you can access by typing
`foo<C-j>` in insert mode.

Filetype-aware snippets are also available. For example, a file called
`main` in `~/.vim/miniSnip/java/main.snip` will create a `main` snippet only when
`filetype=java`, allowing you to add a `main` for C, `main` for C++ and so on.

See [the documentation](doc/miniSnip.txt) to learn the snippet syntax and options.

## Features

  * default values of placeholders (e.g. `<{example}>`)
  * references to previous tags (e.g. `<{~2}>` refers to second placeholder)
  * evaluation of Vim functions (e.g. `<{!expand('%')}>`)
  * ins-completion function
  * `<{+}>` will be targeted last (equivalent of `$0` in UltiSnips)
  * filetype-aware snippets
  * changing delimiters, snippet file filetype etc. (`:h miniSnip-configuration`)
  * local snippets (`:h g:miniSnip_local`)
  * named placeholders (`:h g:miniSnip_named`)
  * global and local to buffer configuration (`:h g:miniSnip-configuration`)

## Examples

* `c/incl.snip`
```
? Include header file
#include "<{!substitute(expand('%:t'), '\.c', '\.h', '')}>"
```

* `html/html.snip`
```
? HTML basic structure
$ `{{` `}}`
<!DOCTYPE html>
<html lang="{{en}}">
<head>
  <meta charset="UTF-8">
  <title>{{Joren}}</title>
  <meta name="author" content="{{~1}}">
  <meta name="description" content="{{}}">
  <meta name="keywords" content="{{example}}">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="{{style.css}}">
</head>
<body>
  {{}}
</body>
</html>
```

* `sql/join_no_match.snip`
```
SELECT <{table1}>.<{ID_1}>
FROM <{~1}>
LEFT JOIN <{table2}> ON <{~1}>.<{~2}> = <{~3}>.<{ID_2}>
WHERE <{~3}>.<{~4}> IS NULL
```

* `sh/wrapper_exec.snip`
```
for dir in $(echo "$PATH" | tr ":" "\n" | grep -Fxv "$(dirname $0)"); do
    [ -x "$dir/$(basename $0)" ] && exec "$dir/$(basename $0)" $@
done
```
---

For more information, see [the documentation](doc/miniSnip.txt).

---

Based on [vim-minisnip](https://github.com/joereynolds/vim-minisnip)

Main differences:
  * reference tags aren't relative, but absolute, i.e. `<{~1}>` will refer to
    first placeholder insted to the previous, `<{~2}>` will refer to the second
    instead of the penultimate
  * references aren't in quotes
  * references to bigger numbers than 9
  * descriptions (`:h g:miniSnip_descmark`)
  * option to change delimiters for specific snippet (`:h g:miniSnip_delimChg`)
  * extending filetypes (`:h g:miniSnip_extends`)
  * cursor at the end of snippets without placeholders, not the beginning
  * directories instead of prefixes for snippets file management
  * respect `expandtab`
  * one final placeholder (`:h g:miniSnip_finalTag`) instead of final delimiters
  * local snippets
  * named placeholders
  * configurable character class used to get snippet name
