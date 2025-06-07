# Entropy Garden

Entropy Garden is a multi-species cellular automaton that explores chaotic evolution and dominance. Each cell belongs to one of five species (or is dead), follows a modified Conway-like rule set with random tie-breaks for births and dominance takeovers, and darkens over time. Noise (random flips) injects entropy each generation, ensuring perpetual dynamism.

---

## Table of Contents
- [Entropy Garden](#entropy-garden)
  - [Table of Contents](#table-of-contents)
  - [About The Project](#about-the-project)
  - [Features](#features)
  - [Built With](#built-with)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
  - [Usage](#usage)
  - [Contact](#contact)

---

## About The Project

Entropy Garden is a five-species cellular automaton written in Lua (using the LÖVE framework). It demonstrates:

- **Darkening Over Time:** Cells fade toward black as they age, and dead cells show a dark red "ghost."
- **Random Tie-Breaks:** If multiple species qualify for birth or dominance, one is chosen at random.
- **Invisible Noise:** A probability-based random flip each generation that isn’t shown until the next frame.
- **Minimalist UI:** A compact bottom-center panel with sliders for speed, fade, noise, and zoom.

---

## Features

- **Multiple Species:** Each cell can be one of five species or dead (0).
- **Conway-Like Logic:** Cells are born or survive if certain neighbor conditions are met, but with random tie resolution.
- **Darkening & Fading:** Live cells darken over time; dead cells fade out in very dark red.
- **Invisible Noise:** Random state flips keep the simulation lively and unpredictable.
- **Horizontal Sliders & Minimal UI:** Adjust speed, fade, noise, and zoom easily.
- **Smooth Zoom & Pan:** Mouse wheel zoom, middle mouse panning.

---

## Built With
- **Lua** – A lightweight scripting language.
- **LÖVE** – A 2D game framework for Lua (optional but recommended for easy graphics).

---

## Getting Started

Follow these instructions to set up and run Entropy Garden on your local machine.

### Prerequisites
- **Lua:** Download from the official Lua website, and install LÖVE2D for `.love` projects.
- **Git:** Download from the official Git website.

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/entropy-garden.git
   ```
2. Navigate to the project directory:
   ```bash
   cd entropy-garden
   ```

3. Run the Application:
   - If using LÖVE:
     ```bash
     love .
     ```
   - If using raw Lua:
     ```bash
     lua main.lua
     ```
  - Or draw the root folder onto love.exe
---

## Usage

1. Launch the application (see “Run the Application” above).
2. Observe the evolving multi-species automaton:
   - Each cell belongs to species 1..5 or is dead (0).
   - Cells darken as they age; dead cells fade out in very dark red.

3. Adjust Sliders at the bottom:
   - **Speed:** 100–5000% update speed.
   - **Fade:** Slower or faster fading for live/dead cells.
   - **Noise:** 0–5% random flips each generation.
   - **Zoom:** 25–200% magnification of the grid.

4. Interact with the grid:
   - **Left-click** to paint species or erase (depending on tool mode).
   - **Middle-click** to pan around.
   - **Mouse wheel** to zoom in/out.

5. Key Controls:
   - `Space` = Pause/Resume simulation
   - `R` = Randomize the grid
   - `0` = Clear the grid
   - `1..5` = Select paint tool (for each species)
   - `E` = Erase tool
   - `D` = Default tool (cycle cell state `0→1→2→3→4→5→0`)
   - **Middle Mouse** = Pan
   - **Mouse Wheel** = Zoom

---

## Contact

Lee Maines – [maineslt@gmail.com](mailto:maineslt@gmail.com)  
Project Link: [https://github.com/maineslt/entropy-garden](https://github.com/maineslt/entropy-garden)

Feel free to open issues or pull requests for suggestions, bug fixes, or enhancements. Enjoy exploring Entropy Garden!
