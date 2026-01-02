# FS25_CabCinematic

A Farming Simulator 25 mod that adds enter-and-exit animations for vehicles.
It’s a standalone mod that doesn’t require any vehicle modifications.

## Installation

1. Go to the [Releases](https://github.com/Templeton-Peck/FS25_CabCinematic/releases) page
2. Download the latest **FS25_CabCinematic.zip** file
3. Place the file in your mods folder

## TODO

### BETA

- [x] Enter/leave cinematics game hook
- [x] Cinematic system with keyframes
- [x] FOV standardization across cameras
- [x] Allow free camera movement during cinematics
- [x] Fix cinematics with moving vehicles
- [x] Improve enter/interact trigger detection (currently too restrictive)
- [x] Cinematic skipping keybind (`left alt` by default)
- [x] Third-person camera fix
- [x] Tab-switching fix
- [x] Handle combine ladder animations properly
- [x] Add view bobbing to cinematics
- [x] Improve animation accuracy using vehicle nodes
- [x] Implement vehicle freezing during cinematics
- [x] Better seat animations
- [x] Minor fovY bug fix
- [x] Fix camera switching
- [x] Minor bug fix with ladders
- [x] Improve old tractors which use narrow doors
- [ ] Fix animation for large tractors which use tracks

### V1

- [ ] Cinematics for all vehicle types
- [ ] modDesc icon
- [ ] Code cleanup

### V1.1

- [ ] Testing with other camera-related mods to prevent conflicts
- [ ] Sounds

### V2

- [ ] Horse support
- [ ] Bike support
- [ ] Multiplayer support (requires help and testing)
- [ ] Full Interactive Control (IC) support

## Acknowledgements

A big thank-you to **w33zl** (https://github.com/w33zl) for all the open-source modding content provided.

## Console Commands

Following console commands are for testing and debugging purposes.

- `ccPauseAnimation` : Pause the current cab cinematic animation.
- `ccSkipAnimation` : Skip animation when entering or exiting a vehicle.
- `ccDebug` : Draw debug gizmos and lines for animation and vehicle.

### Frequently asked questions (FAQ)

> **Q:** Why are the animations not working for my vehicle?
> 
> **A:** The mod relies on specific vehicle properties to create accurate animations. If a vehicle lacks these properties or has unique configurations, the animations may not function correctly. Please report such vehicles for further investigation.

> **Q:** Doors won't open/close during animations. Why?
> 
> **A:** The mod is not designed to provide door animations. To enable door interaction, you’ll need to install the Interactive Control (IC) mod. I’m planning to fully integrate the IC mod for certain vehicles, such as combines, where you’ll need to climb a ladder to access and open the door.

> **Q:** The vehicle camera FOV setting seem to be ignored. Why?
>
> **A:** The mod enforces a consistent FOV for vehicle cameras to ensure a smooth cinematic experience. If you want to adjust the FOV, change the "First Person FOV" option in the game settings.
## Preview

https://github.com/user-attachments/assets/573625d1-088f-496b-9e8a-25be32d2a286

https://github.com/user-attachments/assets/4c978b29-7b1e-40b9-acba-5128765c7beb

https://github.com/user-attachments/assets/7f043281-0dec-4092-a99d-3eba4f6f2eaa

https://github.com/user-attachments/assets/2410b4d6-6498-486b-be15-b04df5f95abc
