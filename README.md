# Emporter CLI

Instantly create secure URLs to your Mac, from the Terminal, by automating _Emporter.app_.

[Watch a quick video](https://emporter.app/video?id=cli&ref=github) to see it in action!

## Installation

1. Download the [latest release](https://github.com/youngdynasty/emporter-cli/releases/latest/download/emporter.pkg) and double-click to install
2. That's it! Type `emporter` from the command-line to get started

#### Installing from the Terminal (alternate method)

Run `curl https://cli.emporter.app | sh` ([view source](https://cli.emporter.app))

The script downloads the latest release, verifies its code signature and installs it using the built-in macOS installer. It does the same thing as the normal installation process, without a GUI.

Use at your discretion. It is less secure in nature (as it pipes a script over HTTPS to `sh`).

_Side note: This really would be ideal as a Homebrew cask. Please star this project to make it a worthy submission!_

## Command usage

### Common commands

#### Creating a new URL

```bash
emporter create some/dir          # serve directory at some/dir
emporter create 8080              # localhost:8080
emporter create mikey.local:8080  # localhost:8080 (Host: mikey.local)
emporter create --rm 9000         # localhost:9000 (removed on exit)
```

URLs are automatically served upon creation by default.

#### Viewing/serving existing URLs

```bash
emporter list   # list previously created urls
emporter run    # serve previously created urls
```

#### Managing URLs

```bash
emporter edit --name wow 8080  # name url to port 8080 "wow"
emporter rm some/dir           # remove url to directory at some/dir
emporter rm 8080               # remove url to port 8080
```

### More options

Run `emporter help [COMMAND]` for any command (such as `create`) to get a full list of options for a command.

Nearly everything you can do from _Emporter.app_ can be done from the command line!

## Contributions

Contributions via Issues or Pull Requests are welcome. 

There aren't contribution guidelines in place (yet?), so please ask before writing a Pull Request. We can come up with sane guidelines together!

## License

BSD 3 Clause. See [LICENSE](https://github.com/youngdynasty/emporter-cli/blob/master/LICENSE).

---

Built proudly using [EmporterKit](https://github.com/youngdynasty/EmporterKit) and [YDCommandKit](https://github.com/youngdynasty/YDCommandKit).

(c) 2019 [Young Dynasty](https://youngdynasty.net) / [@YoungDynastyNet](https://twitter.com/YoungDynastyNet)
