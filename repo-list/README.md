# Gitopolis config

A place to collaborate on a shared list of git repo remote urls and taxonomy via tags, managed in the [gitopolis](https://github.com/timabell/gitopolis) config format so that we can use it to manage locally checked out copies.

The config file is [.gitopolis.toml](.gitopolis.toml)

This serves the following purposes:

- Information gathering
    - A way of collaborating on tagging which repos are for which product/team (taxonomy)
    - Tracking repos that are duplicated/synced across azure-devops and github
    - Cross referencing with architecture diagrams for git repo names
- Local dev
    - Easier checkout of many repos (easier onboarding) (with `gitopolis clone`)
    - `git pull` etc across many repos (using tags to filter to relevant repos)
- Allowing scriptable unix-style inspections across many repos
    - e.g. running lines-of code analysis across many repos
