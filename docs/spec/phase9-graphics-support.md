# Phase 9: Graphics Support (Optional)

**Duration**: 8-10 weeks
**Prerequisites**: Phase 7 (PCIe Infrastructure) complete, Phase 8 recommended but not required
**Next Phase**: Phase 10 (Optimization & Completion)
**Status**: OPTIONAL - Can be skipped

## Overview

Phase 9 adds graphical output capabilities to the operating system, transforming it from a text-only system to one capable of displaying graphical user interfaces. This phase is optional and can be skipped if the focus is on core OS functionality rather than user-facing graphics.

**Core Objective**: Implement framebuffer management, basic graphics primitives, font rendering, and a simple window system to enable graphical applications.

**Important Note**: This phase is marked optional because:
1. Graphics is not essential for understanding core OS concepts
2. Adds significant complexity
3. Time-consuming implementation
4. Can be explored independently after project completion

## Objectives

### Primary Goals
1. Implement VESA (Video Electronics Standards Association) BIOS Extensions support for mode setting
2. Create framebuffer abstraction and management
3. Implement basic 2D graphics primitives (pixels, lines, rectangles)
4. Add bitmap font rendering with text display
5. Create simple window manager with compositing
6. Provide graphics API for user-space applications

### Learning Outcomes
- Graphics hardware architecture and framebuffer operation
- Pixel formats and color spaces
- Rasterization algorithms
- Font rendering techniques
- Window management concepts
- Event handling for GUI applications
- Performance optimization for graphics operations

## Functional Requirements

### FR1: VESA BIOS Extensions (VBE) Support

**Requirement**: Detect available video modes and configure graphics hardware using VESA BIOS Extensions.

**Mode Detection**:

#### Query Available Modes
- Enumerate all supported VESA modes
- Collect mode information:
  - Resolution (width x height)
  - Bits per pixel (8, 16, 24, 32)
  - Framebuffer physical address
  - Bytes per scanline (pitch)
  - Linear framebuffer support
  - Memory model (direct color, indexed)

#### Mode Information Structure
```c
struct vbe_mode_info {
  uint16_t mode_number;
  uint16_t width;
  uint16_t height;
  uint8_t bpp;           // Bits per pixel
  uint8_t memory_model;  // 4 = packed pixel, 6 = direct color
  uint64_t framebuffer_addr;  // Physical address
  uint32_t pitch;        // Bytes per scanline
  uint8_t red_mask_size;
  uint8_t red_field_position;
  uint8_t green_mask_size;
  uint8_t green_field_position;
  uint8_t blue_mask_size;
  uint8_t blue_field_position;
};
```

**Mode Selection**:
- Prefer modes with linear framebuffer access
- Prefer 32 bpp (RGBA8888) for simplicity
- Common resolutions: 640x480, 800x600, 1024x768, 1280x1024
- Validate mode before setting

**Mode Setting**:
- Call BIOS INT 0x10 function 0x4F02 (x86) or use QEMU ramfb/bochs-display (RISC-V)
- Set linear framebuffer bit
- Preserve framebuffer contents if needed
- Handle mode set failure gracefully

**QEMU Considerations**:
- **x86_64** (Phase 11): Use real mode BIOS calls or VBE
- **RISC-V**: QEMU provides virtio-gpu or ramfb devices
  - ramfb: Simple framebuffer in RAM
  - virtio-gpu: More complex but feature-rich
  - Configure via QEMU command line

**Success Criteria**:
- Can enumerate available video modes
- Can select and activate a graphics mode
- Framebuffer accessible and writable
- Mode information correctly extracted
- Fallback to safe mode (e.g., 640x480) if preferred mode unavailable

### FR2: Framebuffer Management

**Requirement**: Provide abstraction layer for framebuffer access with support for different pixel formats and multiple virtual framebuffers.

**Framebuffer Abstraction**:

#### Framebuffer Structure
```c
struct framebuffer {
  uint32_t width;
  uint32_t height;
  uint32_t pitch;        // Bytes per scanline
  uint8_t bpp;           // Bits per pixel
  enum pixel_format format;
  void *buffer;          // Virtual address of framebuffer
  uint64_t buffer_phys;  // Physical address
  size_t buffer_size;
  struct spinlock lock;  // Protect concurrent access
};

enum pixel_format {
  PIXEL_FORMAT_RGB888,   // 24 bpp
  PIXEL_FORMAT_RGBA8888, // 32 bpp
  PIXEL_FORMAT_RGB565,   // 16 bpp
  PIXEL_FORMAT_INDEXED8, // 8 bpp palette
};
```

**Pixel Format Handling**:
- Support RGBA8888 as primary format (32 bpp, 8:8:8:8)
- Conversion functions between formats
- Handle byte ordering (little-endian)
- Pixel format: `[Blue][Green][Red][Alpha]` in memory

**Double Buffering**:
- Maintain front buffer (visible) and back buffer (drawing)
- Swap buffers to eliminate tearing
- Allocate back buffer from kernel memory
- Fast blit operation for buffer swap

**Dirty Region Tracking** (Optional):
- Track modified regions of framebuffer
- Only update changed areas on swap
- Optimize for small updates (e.g., cursor movement)

**Framebuffer Operations**:
```c
// Initialize framebuffer
int fb_init(struct framebuffer *fb, uint32_t width, uint32_t height,
            enum pixel_format format, void *buffer);

// Map framebuffer to kernel virtual memory
void *fb_map(struct framebuffer *fb);

// Allocate back buffer
int fb_alloc_backbuffer(struct framebuffer *fb);

// Swap front and back buffers
void fb_swap_buffers(struct framebuffer *fb);

// Clear framebuffer to color
void fb_clear(struct framebuffer *fb, uint32_t color);
```

**Success Criteria**:
- Framebuffer correctly mapped and accessible
- Can write pixels to framebuffer
- Double buffering reduces tearing
- Concurrent access protected by locks
- Works with different pixel formats

### FR3: Graphics Primitives (2D)

**Requirement**: Implement basic 2D drawing operations for rendering shapes and primitives.

**Drawing Operations**:

#### Pixel Operations
```c
void fb_put_pixel(struct framebuffer *fb, int x, int y, uint32_t color);
uint32_t fb_get_pixel(struct framebuffer *fb, int x, int y);
```
- Bounds checking
- Clipping to framebuffer boundaries
- Alpha blending support (optional)

#### Line Drawing
```c
void fb_draw_line(struct framebuffer *fb, int x0, int y0, int x1, int y1,
                  uint32_t color);
```
- Use Bresenham's line algorithm
- Handle all octants correctly
- Anti-aliasing (optional, advanced)

#### Rectangle Operations
```c
void fb_fill_rect(struct framebuffer *fb, int x, int y, int width, int height,
                  uint32_t color);
void fb_draw_rect(struct framebuffer *fb, int x, int y, int width, int height,
                  uint32_t color);
```
- Filled rectangle: fill interior
- Draw rectangle: outline only
- Clipping to framebuffer

#### Circle Drawing (Optional)
```c
void fb_draw_circle(struct framebuffer *fb, int cx, int cy, int radius,
                    uint32_t color);
void fb_fill_circle(struct framebuffer *fb, int cx, int cy, int radius,
                    uint32_t color);
```
- Use midpoint circle algorithm
- Efficient integer-only math

#### Bitmap Blitting
```c
void fb_blit(struct framebuffer *fb, int x, int y, const void *bitmap,
             int width, int height);
void fb_blit_alpha(struct framebuffer *fb, int x, int y, const void *bitmap,
                   int width, int height);
```
- Copy rectangular region
- Support source transparency
- Alpha blending for anti-aliasing

**Color Representation**:
```c
typedef uint32_t color_t;  // RGBA8888

#define RGB(r,g,b)     ((0xFF << 24) | ((r) << 16) | ((g) << 8) | (b))
#define RGBA(r,g,b,a)  (((a) << 24) | ((r) << 16) | ((g) << 8) | (b))

// Common colors
#define COLOR_BLACK    RGB(0, 0, 0)
#define COLOR_WHITE    RGB(255, 255, 255)
#define COLOR_RED      RGB(255, 0, 0)
#define COLOR_GREEN    RGB(0, 255, 0)
#define COLOR_BLUE     RGB(0, 0, 255)
```

**Success Criteria**:
- All primitives render correctly
- No artifacts or gaps in lines
- Rectangles filled completely
- Performance acceptable (>1000 primitives/frame)
- Clipping works correctly at boundaries

### FR4: Font Rendering

**Requirement**: Implement bitmap font loading and text rendering for displaying textual information.

**Bitmap Font Format**:

#### PSF (PC Screen Font) Format
- Use PSF version 2 format (simple, well-documented)
- Fixed-width fonts (monospaced)
- Common sizes: 8x8, 8x14, 8x16
- Embed font in kernel or load from filesystem

**Font Structure**:
```c
struct psf2_header {
  uint32_t magic;        // 0x864ab572
  uint32_t version;      // 0
  uint32_t headersize;   // Offset of bitmaps in file
  uint32_t flags;        // 0 if no unicode table
  uint32_t numglyph;     // Number of glyphs
  uint32_t bytesperglyph;// Size of each glyph
  uint32_t height;       // Height in pixels
  uint32_t width;        // Width in pixels
};

struct font {
  uint32_t width;
  uint32_t height;
  uint32_t num_glyphs;
  const uint8_t *bitmap;  // Pointer to glyph bitmaps
};
```

**Font Rendering**:
```c
// Render single character
void fb_draw_char(struct framebuffer *fb, int x, int y, char c,
                  const struct font *font, uint32_t fg_color, uint32_t bg_color);

// Render string
void fb_draw_string(struct framebuffer *fb, int x, int y, const char *str,
                    const struct font *font, uint32_t fg_color, uint32_t bg_color);
```

**Glyph Rendering**:
- Each glyph is a bitmap (1 bit per pixel)
- Iterate through rows and columns
- Set foreground color for 1 bits
- Set background color for 0 bits (or transparent)
- Advance x position by glyph width

**Text Layout**:
- Horizontal text flow (left-to-right)
- Line wrapping at framebuffer boundary
- Newline handling ('\n')
- Tab expansion (8 spaces)
- Control character handling (optional)

**Advanced Features** (Optional):
- TrueType font rendering (complex, use library like FreeType)
- Anti-aliased font rendering
- Unicode support (UTF-8 decoding)
- Multiple font faces (bold, italic)
- Subpixel rendering

**Success Criteria**:
- ASCII characters render correctly
- Text readable at common sizes
- No artifacts or missing pixels
- Performance: >10,000 characters/frame
- Works with different fonts

### FR5: Window System

**Requirement**: Implement basic window manager with window creation, management, and compositing.

**Window Structure**:
```c
struct window {
  int id;
  int x, y;              // Position on screen
  int width, height;     // Dimensions
  char title[64];        // Window title
  uint32_t *buffer;      // Window contents (off-screen buffer)
  int z_order;           // Stacking order
  uint32_t flags;        // Visible, focused, etc.
  struct window *next;   // Linked list
};

// Window flags
#define WIN_VISIBLE    (1 << 0)
#define WIN_FOCUSED    (1 << 1)
#define WIN_DECORATED  (1 << 2)  // Title bar, border
#define WIN_RESIZABLE  (1 << 3)
```

**Window Manager Functions**:
```c
// Create window
int wm_create_window(int x, int y, int width, int height, const char *title);

// Destroy window
void wm_destroy_window(int window_id);

// Show/hide window
void wm_show_window(int window_id);
void wm_hide_window(int window_id);

// Move/resize window
void wm_move_window(int window_id, int x, int y);
void wm_resize_window(int window_id, int width, int height);

// Raise/lower window (z-order)
void wm_raise_window(int window_id);
void wm_lower_window(int window_id);

// Focus window
void wm_focus_window(int window_id);

// Get window at position (for mouse clicks)
int wm_get_window_at(int x, int y);
```

**Window Rendering**:

#### Compositing
- Maintain off-screen buffer for each window
- Composite all windows to framebuffer back buffer
- Render in z-order (back to front)
- Clip windows to screen boundaries
- Handle overlapping windows

#### Decorations
- Title bar with window title
- Close button (optional)
- Resize handles (optional)
- Border around window
- Drop shadow (optional)

**Window Drawing API**:
```c
// Application draws to window buffer
void win_draw_pixel(int window_id, int x, int y, uint32_t color);
void win_draw_rect(int window_id, int x, int y, int w, int h, uint32_t color);
void win_draw_string(int window_id, int x, int y, const char *str, uint32_t color);

// Refresh window (trigger composite and display)
void win_refresh(int window_id);
```

**Success Criteria**:
- Can create and display multiple windows
- Windows can overlap correctly
- Can move and resize windows
- Focus management works (click to focus)
- Compositing efficient enough for real-time updates
- Window contents preserved when obscured

### FR6: Input Handling (Keyboard and Mouse)

**Requirement**: Integrate keyboard and mouse input with graphics system for interactive GUI applications.

**Keyboard Input**:
- Reuse existing PS/2 keyboard driver
- Generate keyboard events:
  - Key press
  - Key release
  - Key repeat (optional)
  - Modifiers (Shift, Ctrl, Alt)

**Mouse Input**:

#### PS/2 Mouse Driver
- Initialize PS/2 mouse
- Enable data reporting
- Parse mouse packets (3-byte format):
  - Byte 0: Buttons and overflow flags
  - Byte 1: X movement
  - Byte 2: Y movement
- Handle mouse interrupts

**Mouse State**:
```c
struct mouse_state {
  int x, y;              // Current position
  uint8_t buttons;       // Button state (left, right, middle)
  int8_t wheel;          // Scroll wheel (optional)
};
```

**Event System**:
```c
enum event_type {
  EVENT_KEY_PRESS,
  EVENT_KEY_RELEASE,
  EVENT_MOUSE_MOVE,
  EVENT_MOUSE_BUTTON,
  EVENT_MOUSE_WHEEL,
};

struct event {
  enum event_type type;
  union {
    struct {
      uint8_t keycode;
      uint8_t modifiers;
    } key;
    struct {
      int x, y;
      int dx, dy;
    } mouse_move;
    struct {
      int x, y;
      uint8_t button;  // 0=left, 1=right, 2=middle
      uint8_t pressed;
    } mouse_button;
  };
  uint64_t timestamp;
};
```

**Event Queue**:
- Circular buffer for events
- Queue events from interrupt handlers
- User-space applications poll or block for events
- Event delivery to focused window

**Success Criteria**:
- Keyboard input delivered to focused window
- Mouse cursor visible and follows movement
- Mouse clicks delivered to window under cursor
- Event queue doesn't overflow under normal use
- Responsive input (<20ms latency)

### FR7: User-Space Graphics API

**Requirement**: Provide system call interface for user-space applications to create windows and render graphics.

**Graphics System Calls**:

#### Window Management
```c
int sys_create_window(int x, int y, int width, int height, const char *title);
int sys_destroy_window(int window_id);
int sys_show_window(int window_id);
int sys_map_window_buffer(int window_id, void **buffer);  // Map window buffer to user space
int sys_refresh_window(int window_id);
```

#### Drawing Operations
```c
int sys_draw_pixel(int window_id, int x, int y, uint32_t color);
int sys_draw_rect(int window_id, int x, int y, int w, int h, uint32_t color);
int sys_draw_line(int window_id, int x0, int y0, int x1, int y1, uint32_t color);
int sys_draw_text(int window_id, int x, int y, const char *text, uint32_t color);
int sys_blit(int window_id, int x, int y, const void *bitmap, int w, int h);
```

#### Event Handling
```c
int sys_poll_event(struct event *event);           // Non-blocking
int sys_wait_event(struct event *event, int timeout);  // Blocking
```

**Shared Memory Approach** (Optional Optimization):
- Map window framebuffer to user space
- Application draws directly to buffer
- Call sys_refresh_window() to composite
- Reduces system call overhead

**Success Criteria**:
- User applications can create windows
- Drawing operations work from user space
- Events delivered to applications
- Security: applications can't access other windows' buffers
- Performance: >30 FPS for simple applications

### FR8: Example Applications

**Requirement**: Implement simple graphical applications to demonstrate and test the graphics system.

**Graphical Terminal**:
- Terminal emulator with graphical output
- Display text in window
- Handle input from keyboard
- Scroll buffer for command history
- Color support (foreground/background)

**Simple Paint Program**:
- Drawing canvas
- Draw with mouse (freehand drawing)
- Select colors from palette
- Clear canvas
- Save/load drawings (optional)

**Window Demo**:
- Create multiple windows
- Drag windows (click title bar and move)
- Test window overlap and compositing
- Stress test with many windows

**Clock or Animation**:
- Display animated content
- Update at fixed frame rate
- Test rendering performance

**Success Criteria**:
- All example applications compile and run
- Demonstrate major graphics features
- Provide templates for future GUI applications
- Perform acceptably (>15 FPS for animations)

## Non-Functional Requirements

### NFR1: Performance
- Frame rate: >30 FPS for typical GUI (compositing + rendering)
- Window move/resize: <50ms latency
- Text rendering: >1000 characters per frame
- Primitive drawing: >5000 operations per frame
- Boot time impact: <500ms

### NFR2: Memory Usage
- Framebuffer: Size depends on resolution (e.g., 4MB for 1024x768x32bpp)
- Back buffer: Same as framebuffer
- Window buffers: Per-window allocation (minimize)
- Font data: <100KB for multiple fonts
- Total graphics subsystem: <50MB for typical workload

### NFR3: Portability
- Abstract hardware access through HAL
- Support multiple framebuffer sources (VESA, virtio-gpu, etc.)
- Work on both x86_64 and RISC-V
- Graceful fallback if graphics unavailable

### NFR4: Robustness
- Handle invalid input gracefully (out of bounds drawing)
- Recover from graphics mode failures
- Limit resource usage per application (max windows, buffer size)
- Validate all user-provided parameters

### NFR5: Usability
- Responsive GUI (<50ms input latency)
- Smooth animations (no visible tearing)
- Clear visual feedback for interactions
- Consistent look and feel

## Design Constraints

### DC1: Scope Limitations
- **2D graphics only**: No 3D rendering, no GPU acceleration
- **Software rendering**: All drawing in CPU
- **Simple window manager**: No complex WM features (workspaces, tiling, etc.)
- **Basic compositing**: No complex effects (transparency, blur, etc.)
- **Limited font support**: Bitmap fonts only (no TrueType in Phase 9)

### DC2: Hardware Support
- QEMU emulation: virtio-gpu (RISC-V) or VBE (x86_64)
- No real hardware driver required for Phase 9
- Focus on framebuffer abstraction

### DC3: Architecture Requirements
- Must integrate with hybrid kernel architecture
- Window manager can be user-space server (recommended)
- Graphics API via system calls or IPC

### DC4: Educational Focus
- Emphasize understanding over optimization
- Simple, readable algorithms
- Comprehensive comments
- Prefer clarity over performance (within reason)

## Testing Requirements

### Unit Tests

**Framebuffer Operations**:
- Pixel read/write
- Clipping
- Color format conversion
- Buffer swapping

**Graphics Primitives**:
- Line drawing (all octants)
- Rectangle drawing
- Circle drawing
- Bitmap blitting

**Font Rendering**:
- Glyph bitmap extraction
- Character rendering
- String rendering
- Line wrapping

### Integration Tests (QEMU)

**Framebuffer Initialization**:
- Detect video modes
- Set graphics mode
- Map framebuffer
- Verify writeable

**Window System**:
- Create windows
- Move/resize windows
- Overlap and compositing
- Event delivery

**User-Space Applications**:
- Run graphical terminal
- Run paint program
- Multiple windows simultaneously

### Performance Tests

**Rendering Benchmarks**:
- Primitives per second (pixels, lines, rectangles)
- Text rendering speed (characters/second)
- Compositing speed (windows/frame, FPS)
- Fullscreen clear time

**Latency Measurements**:
- Input-to-display latency
- Window move latency
- Rendering latency

**Stress Tests**:
- Many windows (10+)
- Rapid window creation/destruction
- Continuous animation
- High-frequency input events

## Success Criteria

### Functional Success
- [ ] Graphics mode successfully initialized
- [ ] Framebuffer accessible and writeable
- [ ] All graphics primitives work correctly
- [ ] Font rendering displays readable text
- [ ] Windows create, display, and overlap correctly
- [ ] Mouse and keyboard input functional
- [ ] Example applications run

### Architectural Success
- [ ] Clean separation between graphics layers
- [ ] Hardware abstracted through HAL
- [ ] Window manager independent of kernel core
- [ ] User-space API well-defined
- [ ] Modular and extensible design

### Quality Success
- [ ] >60% code coverage in unit tests
- [ ] All unit tests pass
- [ ] No memory leaks in graphics subsystem
- [ ] No crashes under stress tests
- [ ] Code review approved

### Performance Success
- [ ] Frame rate >30 FPS for typical GUI
- [ ] Input latency <50ms
- [ ] Text rendering >1000 chars/frame
- [ ] Window operations responsive
- [ ] Acceptable memory usage

### Usability Success
- [ ] GUI responsive and smooth
- [ ] No visible tearing or artifacts
- [ ] Applications easy to develop
- [ ] Example applications demonstrate features

## Implementation Strategy

### Phase 9.1: Framebuffer Basics (Weeks 1-2)

**Tasks**:
1. Implement VESA mode detection (x86) or virtio-gpu setup (RISC-V)
2. Set graphics mode
3. Map framebuffer to kernel memory
4. Implement basic pixel read/write
5. Test with color patterns

**Deliverable**: Can display pixels on screen

### Phase 9.2: Graphics Primitives (Weeks 2-3)

**Tasks**:
1. Implement line drawing
2. Implement rectangle drawing
3. Implement circle drawing (optional)
4. Implement bitmap blitting
5. Test all primitives

**Deliverable**: Can draw shapes on screen

### Phase 9.3: Font Rendering (Week 4)

**Tasks**:
1. Load PSF2 font
2. Implement glyph rendering
3. Implement text string rendering
4. Test with various texts
5. Add multiple font sizes

**Deliverable**: Can display text on screen

### Phase 9.4: Window System Basics (Weeks 5-6)

**Tasks**:
1. Design window structure
2. Implement window creation/destruction
3. Implement window list management
4. Implement basic compositing
5. Test with multiple windows

**Deliverable**: Multiple windows display correctly

### Phase 9.5: Input Handling (Week 7)

**Tasks**:
1. Implement PS/2 mouse driver
2. Implement mouse cursor rendering
3. Integrate keyboard input
4. Implement event queue
5. Test input delivery

**Deliverable**: Mouse and keyboard work with GUI

### Phase 9.6: User-Space Integration (Week 8)

**Tasks**:
1. Implement graphics system calls
2. Create user-space library
3. Write example applications
4. Test end-to-end

**Deliverable**: User applications can create GUI

### Phase 9.7: Polish and Optimization (Weeks 9-10)

**Tasks**:
1. Performance optimization
2. Window decorations (title bar, borders)
3. Window manager features (move, resize, focus)
4. Documentation
5. Comprehensive testing

**Deliverable**: Complete, polished graphics system

## Common Pitfalls

### Pitfall 1: Framebuffer Tearing
**Problem**: Visible tearing when updating framebuffer directly.
**Solution**: Use double buffering and VSync (if available) or quick full-frame updates.

### Pitfall 2: Slow Software Rendering
**Problem**: Software rendering too slow for acceptable frame rates.
**Solution**: Optimize hot paths, use dirty region tracking, minimize compositing overhead.

### Pitfall 3: Font Rendering Artifacts
**Problem**: Missing pixels or wrong colors in rendered text.
**Solution**: Carefully implement bitmap extraction. Test with known fonts. Check bit ordering.

### Pitfall 4: Window Overlap Issues
**Problem**: Windows not compositing correctly, z-order issues.
**Solution**: Render in strict z-order. Handle clipping properly. Test overlap cases thoroughly.

### Pitfall 5: Input Event Loss
**Problem**: Mouse clicks or keyboard input lost.
**Solution**: Ensure event queue doesn't overflow. Process events regularly. Use larger buffer.

### Pitfall 6: Memory Exhaustion
**Problem**: Graphics buffers consume too much memory.
**Solution**: Limit number of windows. Limit window sizes. Share buffers where possible.

### Pitfall 7: Security Issues
**Problem**: Applications accessing other windows' buffers.
**Solution**: Validate window IDs. Use separate address spaces. Check permissions on operations.

## References

### Specifications
- **VESA BIOS Extension (VBE) 3.0 Specification** - Video mode programming
- **PSF2 Font Format Specification** - Bitmap font format
- **Framebuffer Device API** (Linux) - Reference framebuffer interface

### Algorithms
- **Bresenham's Line Algorithm** - Efficient line drawing
- **Midpoint Circle Algorithm** - Circle rasterization
- **Compositing and Blending** - Porter-Duff compositing model

### Reference Implementations
- **Linux kernel framebuffer**: `drivers/video/fbdev/` - Framebuffer drivers
- **Linux DRM/KMS**: Modern graphics infrastructure
- **X11/Xorg**: Window system implementation
- **Wayland**: Modern compositor architecture
- **SDL (Simple DirectMedia Layer)**: Cross-platform graphics API

### Learning Resources
- **Computer Graphics: Principles and Practice (3rd Edition)** - Comprehensive graphics reference
- **"Linux Framebuffer" OSDev Wiki** - Practical framebuffer programming
- **"Writing a Simple Framebuffer Driver" Linux Journal** - Framebuffer driver tutorial

### Tools
- **QEMU**: `-device virtio-gpu` for RISC-V graphics
- **VNC/SPICE**: Remote display protocols for testing
- **xev**: X11 event viewer (reference for event handling)

## Appendix A: Bresenham's Line Algorithm

**Pseudocode** (Concept only - implement yourself):
```
function line(x0, y0, x1, y1):
  dx = abs(x1 - x0)
  dy = abs(y1 - y0)
  sx = 1 if x0 < x1 else -1
  sy = 1 if y0 < y1 else -1
  err = dx - dy

  while true:
    plot(x0, y0)
    if x0 == x1 and y0 == y1:
      break
    e2 = 2 * err
    if e2 > -dy:
      err -= dy
      x0 += sx
    if e2 < dx:
      err += dx
      y0 += sy
```

**Key Insight**: Uses only integer arithmetic, very efficient.

## Appendix B: PSF2 Font Format

**Header Structure** (20 bytes):
```
Offset  | Field         | Size | Description
--------|---------------|------|-----------------------------
0       | magic         | 4    | 0x864ab572 (PSF2_MAGIC)
4       | version       | 4    | 0
8       | headersize    | 4    | Offset to bitmaps (32)
12      | flags         | 4    | 0 (no unicode table)
16      | numglyph      | 4    | Number of glyphs (usually 256)
20      | bytesperglyph | 4    | Size of each glyph bitmap
24      | height        | 4    | Glyph height in pixels
28      | width         | 4    | Glyph width in pixels
```

**Bitmap Data**: Starts at offset 32, glyphs stored sequentially. Each glyph is `bytesperglyph` bytes, representing `height` rows of `width` pixels (1 bit per pixel, packed).

## Appendix C: Example Window Creation

**User-Space Code**:
```c
#include "graphics.h"

int main() {
  // Create window
  int win = sys_create_window(100, 100, 400, 300, "My Window");
  if (win < 0) {
    printf("Failed to create window\n");
    return 1;
  }

  // Show window
  sys_show_window(win);

  // Draw some content
  sys_draw_rect(win, 0, 0, 400, 300, COLOR_WHITE); // Clear to white
  sys_draw_text(win, 10, 10, "Hello, Graphics!", COLOR_BLACK);
  sys_draw_line(win, 0, 0, 400, 300, COLOR_RED);

  // Refresh to display
  sys_refresh_window(win);

  // Event loop
  struct event ev;
  while (1) {
    sys_wait_event(&ev, -1);  // Block for event

    if (ev.type == EVENT_MOUSE_BUTTON && ev.mouse_button.pressed) {
      printf("Mouse clicked at (%d, %d)\n",
             ev.mouse_button.x, ev.mouse_button.y);
    }

    if (ev.type == EVENT_KEY_PRESS && ev.key.keycode == KEY_ESCAPE) {
      break;  // Exit on ESC
    }
  }

  // Cleanup
  sys_destroy_window(win);
  return 0;
}
```

---

**Phase Status**: Specification Complete (OPTIONAL)
**Estimated Effort**: 320-400 hours over 8-10 weeks
**Prerequisites**: Phase 7 complete (PCIe for virtio-gpu), Phase 8 recommended
**Outputs**: Working graphics system, window manager, example GUI applications
**Next Phase**: [Phase 10: Optimization & Completion](phase10-optimization-completion.md)
**Note**: This phase can be skipped entirely if graphics is not a priority. The project is complete and educational without Phase 9.
