import pygame
import random
import sys

# Grid dimensions
GRID_WIDTH = 80
GRID_HEIGHT = 60
CELL_SIZE = 10

# Zoom limits
MIN_ZOOM = 0.25
MAX_ZOOM = 2.0

BASE_INTERVAL = 0.1

# Colors for species 1..5
SPECIES_COLORS = [
    (255, 0, 0),    # species 1 - red
    (0, 255, 0),    # species 2 - green
    (0, 0, 255),    # species 3 - blue
    (255, 255, 0),  # species 4 - yellow
    (255, 0, 255),  # species 5 - magenta
]
DARK_RED = (64, 0, 0)

class Slider:
    def __init__(self, x, y, width, value=0.0):
        self.rect = pygame.Rect(x, y, width, 12)
        self.value = value
        self.dragging = False

    def handle_event(self, event):
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if self.rect.collidepoint(event.pos):
                self.dragging = True
        elif event.type == pygame.MOUSEBUTTONUP and event.button == 1:
            self.dragging = False
        elif event.type == pygame.MOUSEMOTION and self.dragging:
            rel_x = event.pos[0] - self.rect.x
            self.value = max(0.0, min(1.0, rel_x / self.rect.width))

    def draw(self, surface):
        pygame.draw.rect(surface, (60, 60, 60), self.rect)
        knob_x = self.rect.x + int(self.value * self.rect.width)
        pygame.draw.rect(surface, (200, 200, 200), (knob_x-2, self.rect.y-2, 4, self.rect.height+4))


def get_speed_multiplier(v):
    return 1.0 + 49.0 * (v ** 2)

def get_fade_multiplier(v):
    return 1.0 + 49.0 * (v ** 2)

def get_noise_chance(v):
    return 0.05 * v

def main():
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("Entropy Garden (Python)")
    clock = pygame.time.Clock()

    cells = [[0 for _ in range(GRID_WIDTH)] for _ in range(GRID_HEIGHT)]
    ages = [[0 for _ in range(GRID_WIDTH)] for _ in range(GRID_HEIGHT)]

    pan_x = 0
    pan_y = 0
    zoom_val = 0.0
    zoom = MIN_ZOOM + (MAX_ZOOM - MIN_ZOOM) * zoom_val
    panning = False
    pan_start = (0, 0)
    mouse_start = (0, 0)

    # sliders
    slider_y = 560
    speed_slider = Slider(200, slider_y, 120, 0.0)
    fade_slider = Slider(340, slider_y, 120, 0.0)
    noise_slider = Slider(480, slider_y, 120, 0.0)
    zoom_slider = Slider(620, slider_y, 120, 0.0)
    sliders = [speed_slider, fade_slider, noise_slider, zoom_slider]

    running = True
    paused = False
    update_timer = 0.0
    tool = 1

    def count_neighbors(x, y):
        counts = [0, 0, 0, 0, 0, 0]
        for j in (-1, 0, 1):
            for i in (-1, 0, 1):
                if i == 0 and j == 0:
                    continue
                nx = (x + i) % GRID_WIDTH
                ny = (y + j) % GRID_HEIGHT
                val = cells[ny][nx]
                counts[val] += 1
        return counts

    while running:
        dt = clock.tick(60) / 1000.0
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    paused = not paused
                elif event.key == pygame.K_r:
                    for y in range(GRID_HEIGHT):
                        for x in range(GRID_WIDTH):
                            cells[y][x] = random.randint(0, 5)
                            ages[y][x] = 1 if cells[y][x] != 0 else 0
                elif event.key == pygame.K_0:
                    for y in range(GRID_HEIGHT):
                        for x in range(GRID_WIDTH):
                            cells[y][x] = 0
                            ages[y][x] = 0
                elif pygame.K_1 <= event.key <= pygame.K_5:
                    tool = event.key - pygame.K_0
                elif event.key == pygame.K_e:
                    tool = 0
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 2:
                    panning = True
                    pan_start = (pan_x, pan_y)
                    mouse_start = event.pos
                elif event.button == 1:
                    for s in sliders:
                        s.handle_event(event)
                    if not any(s.dragging for s in sliders):
                        mx, my = event.pos
                        gx = int((mx - pan_x) / (CELL_SIZE * zoom))
                        gy = int((my - pan_y) / (CELL_SIZE * zoom))
                        if 0 <= gx < GRID_WIDTH and 0 <= gy < GRID_HEIGHT:
                            cells[gy][gx] = tool
                            ages[gy][gx] = 1 if tool != 0 else 0
            elif event.type == pygame.MOUSEBUTTONUP:
                if event.button == 2:
                    panning = False
                elif event.button == 1:
                    for s in sliders:
                        s.handle_event(event)
            elif event.type == pygame.MOUSEMOTION:
                for s in sliders:
                    s.handle_event(event)
                if panning:
                    dx = event.pos[0] - mouse_start[0]
                    dy = event.pos[1] - mouse_start[1]
                    pan_x = pan_start[0] + dx
                    pan_y = pan_start[1] + dy
            elif event.type == pygame.MOUSEWHEEL:
                zoom_slider.value = max(0.0, min(1.0, zoom_slider.value + event.y * 0.05))
        # update slider values
        speed_multiplier = get_speed_multiplier(speed_slider.value)
        fade_multiplier = get_fade_multiplier(fade_slider.value)
        noise_chance = get_noise_chance(noise_slider.value)
        zoom = MIN_ZOOM + (MAX_ZOOM - MIN_ZOOM) * zoom_slider.value

        update_interval = BASE_INTERVAL / speed_multiplier
        update_timer += dt
        if not paused and update_timer >= update_interval:
            update_timer = 0.0
            new_cells = [[0 for _ in range(GRID_WIDTH)] for _ in range(GRID_HEIGHT)]
            new_ages = [[0 for _ in range(GRID_WIDTH)] for _ in range(GRID_HEIGHT)]
            for y in range(GRID_HEIGHT):
                for x in range(GRID_WIDTH):
                    val = cells[y][x]
                    neighbors = count_neighbors(x, y)
                    if val == 0:
                        candidates = [s for s in range(1, 6) if neighbors[s] == 3]
                        if candidates:
                            new_val = random.choice(candidates)
                            new_cells[y][x] = new_val
                            new_ages[y][x] = 1
                        else:
                            new_cells[y][x] = 0
                            if ages[y][x] < 0:
                                new_ages[y][x] = ages[y][x] - 1
                            else:
                                new_ages[y][x] = -1 if ages[y][x] != 0 else 0
                    else:
                        same = neighbors[val]
                        if same == 2 or same == 3:
                            new_cells[y][x] = val
                            new_ages[y][x] = ages[y][x] + 1
                        else:
                            max_n = max(neighbors[1:])
                            if max_n > same:
                                candidates = [s for s in range(1, 6) if neighbors[s] == max_n]
                                new_val = random.choice(candidates)
                                new_cells[y][x] = new_val
                                new_ages[y][x] = 1
                            else:
                                new_cells[y][x] = 0
                                new_ages[y][x] = -1
            # apply noise
            for y in range(GRID_HEIGHT):
                for x in range(GRID_WIDTH):
                    if random.random() < noise_chance:
                        new_val = random.randint(0, 5)
                        new_cells[y][x] = new_val
                        new_ages[y][x] = 1 if new_val != 0 else -1
            cells = new_cells
            ages = new_ages

        screen.fill((0, 0, 0))

        for y in range(GRID_HEIGHT):
            for x in range(GRID_WIDTH):
                val = cells[y][x]
                age = ages[y][x]
                if val == 0 and age <= 0:
                    brightness = max(0.0, 1.0 + age * 0.05 * fade_multiplier)
                    if brightness > 0:
                        color = [int(c * brightness) for c in DARK_RED]
                        rect = pygame.Rect(pan_x + x * CELL_SIZE * zoom,
                                           pan_y + y * CELL_SIZE * zoom,
                                           CELL_SIZE * zoom, CELL_SIZE * zoom)
                        pygame.draw.rect(screen, color, rect)
                elif val != 0:
                    brightness = max(0.0, 1.0 - age * 0.05 * fade_multiplier)
                    base = SPECIES_COLORS[val - 1]
                    color = [int(c * brightness) for c in base]
                    rect = pygame.Rect(pan_x + x * CELL_SIZE * zoom,
                                       pan_y + y * CELL_SIZE * zoom,
                                       CELL_SIZE * zoom, CELL_SIZE * zoom)
                    pygame.draw.rect(screen, color, rect)

        for s in sliders:
            s.draw(screen)

        pygame.display.flip()

    pygame.quit()

if __name__ == "__main__":
    main()
