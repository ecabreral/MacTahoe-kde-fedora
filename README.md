<img src="https://github.com/vinceliuice/MacTahoe-gtk-theme/raw/main/Tahoe.png" alt="Logo" align="right" /> MacTahoe KDE Theme
======

MacTahoe kde is a MacOS Tahoe like theme for KDE Plasma desktop.

## Donate

If you like my project, you can donate at:

<span class="paypal"><a href="https://www.paypal.me/vinceliuice" title="Donate to this project using Paypal"><img src="https://www.paypalobjects.com/webstatic/mktg/Logo/pp-logo-100px.png" alt="PayPal donate button" /></a></span>

## Installation

```sh
./install.sh
```

## My plasma shell settings

![panel_settings](panel_settings.jpg)

## Recommendations
- For gtk app blur Effect you can use this extension [kwin-effects-forceblur](https://github.com/taj-ny/kwin-effects-forceblur).

  Go to `System Sttings` > `Window Management` > `Desktop Effects` > `Better Blur` turn it on

  1. Open `Better Blur` Configure window > `Force blur` active `Blur all except matching`

  2. Open `Rounded corners` > set window top corner radius to `24` and window bottom corner radius to `24`

![blur_settings](blur_settings.png)

- For better looking please use this pack with [Kvantum engine](https://github.com/tsujan/Kvantum/blob/master/Kvantum/INSTALL.md#distributions).

  Run `kvantummanager` to choose and apply **MacTahoe** theme.

- Install [MacTahoe icon theme](https://github.com/vinceliuice/MacTahoe-icon-theme) for a more consistent and beautiful experience.

- Install [MacTahoe cursors theme](https://github.com/vinceliuice/MacTahoe-icon-theme/tree/main/cursors) for a more consistent and beautiful experience.

## preview

![light](plasma/look-and-feel/com.github.vinceliuice.MacTahoe-Light/contents/previews/fullscreenpreview.jpg)
![dark](plasma/look-and-feel/com.github.vinceliuice.MacTahoe-Dark/contents/previews/fullscreenpreview.jpg)

## Local provisioning (Fedora KDE / Plasma 6)

This repository also carries a **local, reproducible setup for Fedora KDE Plasma 6** (tested on Fedora 44,
Plasma 6.6.4, Qt 6.10.2, Wayland, inside a GNOME Boxes VM), plus the compatibility patches needed for Plasma 6.6
(the `org.kde.plasma.icontasks` applet no longer exists and several `defaults` entries are not applied by
`lookandfeeltool`).

See **[fedora/README.md](fedora/README.md)** for requirements, usage, verification, rollback and troubleshooting.

Quick start from the host:

```sh
ssh-copy-id user@VM_IP
./fedora/setup-remote.sh user@VM_IP
```


