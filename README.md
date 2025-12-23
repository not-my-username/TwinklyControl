# TwinklyControl

**TwinklyControl** is a simple program that lets you control Twinkly LED lights using **Art-Net (DMX over IP)**.

![Screenshot of the TwinklyControl user interface.](https://raw.githubusercontent.com/not-my-username/TwinklyControl/refs/heads/master/.github/UI.png)

## Overview

- Art-Net input can be received on **any network interface**
- Twinkly devices are **automatically discovered** on all available network interfaces
- Each Twinkly device is mapped to a DMX address using a configurable universe and channel offset

## DMX Addressing

You can set the DMX start address for each Twinkly device using:

```
universe.channel
```

- **Universe** is **zero-indexed** (Universe 0, 1, 2, …)
- **Channel** is **one-indexed** (Channel 1–512)

This address acts as the offset that determines which DMX channels the Twinkly device listens to.

## Pixel Configuration

- The number of pixels on each Twinkly device is **automatically detected**
- You must configure how many **DMX channels per pixel** are used:
  - `3` for RGB
  - `4` for RGBW or DRGB
  - `...`

This information allows the software to correctly calculate how many DMX channels are required for each device.

---

© 2025 [Liam Sherwin](https://liamsherwin.com).  
Licensed under the GNU General Public License v3.0. See the LICENSE file for details.
