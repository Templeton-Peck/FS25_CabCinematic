# FS25_CabCinematic

A Farming Simulator 25 mod that adds enter-and-exit animations for vehicles.
It’s a standalone mod that doesn’t require any vehicle modifications.

## Installation

1. Go to the [Releases](https://github.com/Templeton-Peck/FS25_CabCinematic/releases) page
2. Download the latest **FS25_CabCinematic.zip** file
3. Place the file in your mods folder

## Supported Vehicles (WIP)

- Tractors
  - ✅ Small Tractors
  - ✅ Medium Tractors
  - ✅ Large Tractors
  - ✅ Track Tractors
- Combines
  - ✅ Harvesters
  - ✅ Forage Harvesters
  - ✅ Sugar Beet Harvesters
  - ✅ Olive Harvesters
  - ✅ Grape Harvesters
  - ✅ Sugarcane Harvesters
  - ✅ Rice Harvesters
  - ✅ Potato Harvesters
  - 🟨 Green Bean Harvesters 
  - 🟨 Spinach Harvesters
  - ⬜ Pea Harvesters
  - ⬜ Cotton Harvesters
  - ⬜ Vegetable Harvesters
  - ⬜ Beet Loaders
- Loaders
  - ✅ Wheel Loaders
  - ✅ Front Loaders
  - ✅ Forklifts
  - ⬜ Skid Steers
- Telehandlers
  - ✅ Standards
  - ✅ Moving cabs
- Sprayers
  - ✅ Standards
- Forestry
  - ⬜ Harvesters
  - ⬜ Forwarders
  - ⬜ Excavators
  - ⬜ Others
- Road Vehicles
  - ⬜ Trucks
  - ⬜ Cars
  - ⬜ Bikes
  - ⬜ Others

## Known bugs

- Conflict with mod FS25_MoreVisualAnimals (No enter animation)
- Camera clipping after leaving a vehicle

## Key bindings

- `Skip current animation` : Press enter/leave vehicle key to skip the current animation and immediately switch to the vehicle.
- `Pause/Resume cab cinematic` : Maintain `left alt` to pause/resume the cab cinematic animation when it’s active.

## TODO

### BETA

- [x] Try/Fix vehicle without physical cab
- [x] Animations accuracy improvements
- [ ] Fix camera clipping right after leaving vehicle

### V1

- [ ] Cinematics for all vehicle types
- [ ] modDesc icon
- [ ] Code cleanup

### V1.1

- [ ] Testing with other camera-related mods to prevent conflicts
- [ ] Multiplayer support (requires help and testing)
- [ ] Track IR support
- [ ] Full Interactive Control (IC) support
- [ ] Passenger mode support

### V2

- [ ] Sounds
- [ ] Horse support
- [ ] Bike support

## Acknowledgements

A big thank-you to **w33zl** (https://github.com/w33zl) for all the open-source modding content provided.

## Console Commands

Following console commands are for testing and debugging purposes.

- `ccDebug` : Draw debug gizmos and lines for animation and vehicle.

### Frequently asked questions (FAQ)

> **Why are the animations not working for my vehicle?**  
> *The mod relies on specific vehicle properties to create accurate animations. If a vehicle lacks these properties or has unique configurations, the animations may not work correctly. Please report such vehicles for further investigation.*

> **Doors won't open/close during animations. Why?**  
> *The mod is not designed to provide door animations. To enable door interaction, you’ll need to install the Interactive Control (IC) mod. I’m planning to fully integrate the IC mod for certain vehicles, such as combines, where you’ll need to climb a ladder to access and open the door.*

> **The vehicle camera FOV setting seem to be ignored. Why?**  
> *The mod enforces a consistent FOV for vehicle indoor cameras to ensure a smooth cinematic experience. If you want to adjust the FOV, change the "First Person FOV" option in the game settings.*

> **I can't enter vehicle sometimes. Why?**  
> *The mod assumes the player is positioned near the vehicle’s entry point to maintain realistic behavior. If you are too far away, standing behind the vehicle, or on the opposite side, entering the vehicle won't be possible.*

## Preview

https://github.com/user-attachments/assets/573625d1-088f-496b-9e8a-25be32d2a286

https://github.com/user-attachments/assets/4c978b29-7b1e-40b9-acba-5128765c7beb

https://github.com/user-attachments/assets/7f043281-0dec-4092-a99d-3eba4f6f2eaa

https://github.com/user-attachments/assets/2410b4d6-6498-486b-be15-b04df5f95abc
