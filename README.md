![Banner](/forge-banner.png)

<div align="center">
  <a href="https://docs.zilibobi.dev/vfx-forge"><img alt="View Documentation" src="https://img.shields.io/badge/Documentation-View?style=for-the-badge&label=View&color=c4a7e7"></a>
  <a href="https://discord.gg/Qme9KPN3pF"><img alt="Join Discord" src="https://img.shields.io/discord/1401872327162986626?logo=discord&style=for-the-badge&color=c4a7e7&logoColor=ffffff&label=Join%20Discord"></a>
</div>

# Emit Module

This is a fork of the emit module provided by the <a href="https://devforum.roblox.com/t/3867553">VFX Forge</a> Roblox plugin, made from [zilibobi/forge-vfx](https://github.com/zilibobi/forge-vfx) after 2.4.0. It adds a playback rate, so every effect can be slowed down, sped up or frozen while it plays.

```luau
vfx.setRate(2) -- every effect, including ones already playing, runs twice as fast
vfx.setRate(0) -- every effect freezes where it is
vfx.track(workspace.Map) -- enabled emitters, beams, trails and sounds the engine runs by itself follow the rate too
```

The rate covers delays, durations, tweens, flipbooks, particles, beams, trails, sounds, camera shakes and debris. Particles can't run faster than a TimeScale of 1, so an emitter authored at a TimeScale of 0.25 can be sped up to 4x. Debris keeps its path at any rate by scaling its velocity and the gravity on it.

## License
The emit module is licensed under a custom source-available copyleft license which **<mark>only allows usage within Roblox games</mark>**. This fork is under the same license.

## Installation

#### Wally (Luau)

```sh
ForgeVFX = "josephh310/forge-vfx@1.0.1"
```

## Usage

The module needs to be initialized before emitting any effects.
After that it is also exposed inside `shared.vfx`.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vfx = require(ReplicatedStorage.ForgeVFX)

vfx.init()
vfx.emit(workspace.Effect)
```
