# Fzf simple completion
Pipe bash tab-completion suggestions into ``fzf`` fuzzy finder

<a href="https://asciinema.org/a/675226" target="_blank"><img src="https://asciinema.org/a/675226.svg" width=75%/></a>

## Prerequisites
- [fzf](https://github.com/junegunn/fzf) (command-line fuzzy finder)
- [bash-completion](https://github.com/scop/bash-completion) (most Linux distros ship ``bash-completion`` by default, so there is less chance you will have to install it)

## Quick start
Source ``fzf-simple-completion.sh`` at the end of your ``.bashrc``. For example:
```sh
source ~/path/fzf-simple-completion.sh
```
This will replace the default bash completion by fzf selection menu whenever you hit ``TAB``.
## Features
- Commands and arguments completion
- Directories shortening 
- Color support
## How does it work?
This project is motivated by [Accessing tab-completion programmatically in Bash](https://brbsix.github.io/2015/11/29/accessing-tab-completion-programmatically-in-bash/). You may find some alternatives on Github as well, but the implementations looks overwhelming to me (I'm not a bash guru so I want to keep things as clean and manageable as possible).

The idea this project works on is straightforward: 
- Pipe all suggestions from ``bash-completion`` directly into ``fzf`` for easy search and selection.

There is an extra work to make the complettion handle directories with spaces, shortening paths, and coloring. The script itself is written in just a few lines of code, making it easy to modify and customize as needed.




