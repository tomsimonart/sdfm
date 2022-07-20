## Installation

* `git clone git@github.com:tomsimonart/sdfm.git`
* `cd sdfm`
* `make install` to install locally for this user or `sudo make TARGET=/usr/local/bin install` to install for all users
* To update use `git pull` no need to re-install

If you already have a git repository with your tracked dotfiles:

* `sdfm git clone <repo path> .`
* `sdfm install`

If you don't, here is how to initialize it:

* `sdfm git init`
* Track some dotfiles with `sdfm track PATH` (more explanations [here](#tracking-files-with-the-storage))
* `sdfm git add .`
* `sdfm git commit -m 'Initial commit'`
* Add your favorite remote and push the commit upstream

## Tracking files with the storage

The storage is a folder where your dotfiles are moved, the original path is then replaced by a simlink to the storage.
By default this folder is located in `$HOME/.sdfm/storage/`.
To track your dotfiles you also need to track `$HOME/.sdfm/track_file`.
Therefore the git repository containing your dotfiles should exist in the `$HOME/.sdfm/` directory.
As a helper you can use the `sdfm git <git cmd>` command to do things like `sdfm git add . --patch`, the command will run git in the correct directory.

* To track a new file: `sdfm track <your file>`
* To untrack a file: `sdfm untrack <your file>`
* To list tracked files: `sdfm list`
* To update files after pulling the storage: `sdfm install`
