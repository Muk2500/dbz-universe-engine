# DBZ Universe: Interactive E-Comic

An interactive multimedia application and digital archive built in ActionScript 3.0 (Adobe Animate). ActionScript was enforced by the university as the required language for this module, which inspired the challenge to push an outdated engine to its absolute technical limits. The Dragon Ball Z theme was chosen out of pure passion for the franchise, and the application is filled with hidden easter eggs, lore-accurate combat data, and procedural simulations.

This project explores the narrative of the Frieza Saga while functioning as a complex, object-oriented state machine with physics-based scrolling, custom mini-games, and dynamic media loading.

## Technical Highlights

* **Monolithic State Machine Architecture**
  The core application utilizes a centralized state controller to handle module instantiation and garbage collection. This ensures minimal memory leaks and a stable 60FPS refresh rate across the entire experience.

* **Physics-Based UI Navigation**
  The vertical manga reader implements custom Linear Interpolation (Lerp) logic. It calculates velocity and applies a constant friction coefficient to simulate organic momentum rather than relying on native timeline tweens.

* **AABB Collision & Gravity Simulation**
  The embedded "Z-Runner" mini-game features a procedural obstacle generator. It bypasses native hitTestObject functions in favor of custom Axis-Aligned Bounding Box (AABB) intersection math and gravity algorithms for pixel-perfect collision detection.

* **Asynchronous Media Streaming**
  High-definition MP4 cutscenes are loaded dynamically via the NetStream and NetConnection classes. This keeps the core executable lightweight and explicitly clears the video buffer to free RAM upon exit.

* **Dynamic Audio Engine**
  A custom audio controller manages contextual BGM zones and one-shot SFX layers. It handles programmatic crossfading using the SoundTransform class and Timer events to interpolate volume changes smoothly.

## Project Structure

* `/as3/` - Contains all custom ActionScript 3.0 class files governing the application logic.
* `/assets/` - External MP4 videos and high-fidelity graphics.
* `DBZ_Universe.fla` - The primary Adobe Animate authoring file.

## Setup and Execution

1. Open `DBZ_Universe.fla` in Adobe Animate CC.
2. Ensure the ActionScript 3.0 settings point to the `/as3/` source directory.
3. Press `Ctrl + Enter` to compile the SWF and launch the application.

*Note: Large video files in the assets folder may be omitted from this repository due to GitHub size limits.*
