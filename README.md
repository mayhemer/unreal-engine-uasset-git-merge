# Unreal Engine binary uasset merge and diff tools integration into git

This is a set of scripts that add `git difftool` and `git mergetool` for Unreal Engine `.uasset` files.
It can be useful for resolving conflicts when rebasing a local branch to master or merging master into a local branch.

I specifically created this for `git rebase TargetBranch` and for plugins being git submodules, for whome the Unreal Editor source control feature doesn't work.

NOTE: The scripts runs against the default project binaries configuration (usually "Development".)  Make sure that your C++ code is built for the default project target and configuration.  Otherwise, you can see errors in the graphs that are false-negatives as nodes calling UFUNCTIONs may not see the latest changes.

## Setup

- Clone the repo to a directory best w/o spaces in the path.
- The `/install.ps1` script installs the merge and diff tools to your `~/.gitconfig` and adds directory with public scripts to `PATH` to be used in Windows git-bash prompt.  Simply run this installation script from its location.
- Restart git-bash terminal.

## Environemnt variables to (optionally) configure

- `UE_INSTALL_PATH`  
  The merge tool looks for Unreal Engine editor executable default installtion in registry, currently only looks for UE 5.2.  If you are using a custom build or a different version, set `UE_INSTALL_PATH` env var to point at the Unreal Engine installation root (the directory where `Engine/Binaries` resides)

## Public git-bash scripts to use

* `git_ue_diff`  
  Shows a diff of asset file(s) between two commits or in a commit range (the .. notation)  
  Run this script in the root directory of the project or plugin you want to make the diff in.  
  Takes two or three arguments:
  - `commit_id1` `commit_id2` `Content/Path/[File.uasset]`
  - `child_commit_id..parent_commit_id` `Content/Path/[File.uasset]`
  
  If you provide only a directory instead of a specific file, it will run the diff tool for all modified files in that directory, recursively.

* `git_ue_diff_my` and `git_ue_diff_theirs`  
  Useful for viewing conflicting files diffs when rebasing/merging a branch to view our and their changes respectively.  
  Again, run in the root directory of a project or plugin.  
  Takes only one argument:
  - relative path to the conflicting `.uasset` file to see the diff of

* `git_ue_merge`  
  Invokes the 3-pane Unreal's merge diff-tool.
  Run in the root directory of a project or plugin.  
  Takes only one argument:
  - relative path to the conflicting `.uasset` file to see the diff of
