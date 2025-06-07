# Entropy Garden (Python Version)

This is a Python recreation of the original **Entropy Garden** cellular automaton.
It implements the same five-species rules with random tie breaks, cell darkening,
and invisible noise using the Pygame library.

## Requirements

- Python 3
- `pygame` (install via `pip install -r requirements.txt`)

## Running

```
python python_version/entropy_garden.py
```

Use the sliders at the bottom to adjust speed, fade, noise, and zoom. The mouse
wheel also controls zoom, and the middle mouse button pans the view.

Keyboard shortcuts:

- `Space` – pause/resume
- `R` – randomize grid
- `0` – clear grid
- `1`..`5` – select paint species
- `E` – erase mode

The original Lua implementation is preserved in the `legacy_lua/` folder.
