package main

import "base:intrinsics"
import "core:c"
import "core:c/libc"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import ray "vendor:raylib"


Color :: ray.Color
Rectangle :: ray.Rectangle

SCREEN_WIDTH :: 1000
SCREEN_HEIGHT :: 800
SCREEN_TITLE :: "Perico"

// UI Constants
COLOR_SLIDER :: ray.GRAY
COLOR_SLIDER_SELECTOR :: ray.BLACK
COLOR_BACKGROUND :: Color{0x10, 0x10, 0x10, 0xff}

app: App

App :: struct {
	canvas:       Canvas,
	active_color: Color,
}

Canvas :: struct {
	data:          []Color,
	width, height: int,
	boundary:      ray.Rectangle,
	text:          ray.Texture2D,
	grid:          ray.RenderTexture2D,
}

color_sliders :: proc(boundary: Rectangle) -> bool {
	@(static)
	dragging: [3]bool
	colors := [3]Color {
		Color{0xff, 0x00, 0x00, 0xff},
		Color{0x00, 0xff, 0x00, 0xff},
		Color{0x00, 0x00, 0xff, 0xff},
	}
	sliders_boundary := boundary
	sliders_boundary.height *= 0.75
	for i in 0 ..< 3 {
		slider_rect := Rectangle {
			sliders_boundary.x,
			sliders_boundary.y + sliders_boundary.height * 0.33 * f32(i),
			sliders_boundary.width,
			sliders_boundary.height * 0.33,
		}
		hslider(&(app.active_color[i]), 0, 255, colors[i], slider_rect, &dragging[i])
	}
	color_bar := Rectangle {
		boundary.x + boundary.width * 0.2,
		boundary.y + sliders_boundary.height,
		boundary.width * 0.6,
		boundary.height - sliders_boundary.height,
	}
	ray.DrawRectanglePro(color_bar, {}, 0, app.active_color)
	return dragging[0] || dragging[1] || dragging[2]
}

hslider :: proc(
	value: ^$T,
	min, max: T,
	selector_color: Color,
	boundary: ray.Rectangle,
	dragging: ^bool,
) where intrinsics.type_is_numeric(T) {
	valf := f32(value^)
	maxf := f32(max)
	minf := f32(min)
	start_pos := ray.Vector2{boundary.x + boundary.width / 8, boundary.y + boundary.height / 2}
	end_pos := ray.Vector2{boundary.x + boundary.width / 8 * 7, boundary.y + boundary.height / 2}
	ray.DrawLineEx(start_pos, end_pos, boundary.height / 4, COLOR_SLIDER)

	// (value / (max - min)) * (start_pos.x - end_pos.x) 

	selector_center := ray.Vector2 {
		(end_pos.x - start_pos.x) * valf / (maxf - minf) + start_pos.x,
		start_pos.y,
	}

	ray.DrawCircleV(selector_center, boundary.height / 3, selector_color)

	mouse_pos := ray.GetMousePosition()
	if ray.CheckCollisionPointRec(mouse_pos, boundary) && ray.IsMouseButtonPressed(.LEFT) {
		dragging^ = true
	}
	if dragging^ {
		if ray.IsMouseButtonDown(.LEFT) {
			dragging^ = true
			valf = (mouse_pos.x - start_pos.x) / (end_pos.x - start_pos.x) * (maxf - minf) + minf
			if valf < minf {
				valf = minf
			} else if valf > maxf {
				valf = maxf
			}
			value^ = cast(T)valf
		} else {
			dragging^ = false
		}
	}
}

canvas_save_ppm :: proc(filename: string) {
	using app
	file, err := os.open(filename, os.O_WRONLY | os.O_CREATE, os.S_IRUSR | os.S_IWUSR)
	defer {
		os.close(file)
		if err != os.ERROR_NONE {
			fmt.printfln("ERROR: Error closing file `%s`: %s", filename, libc.strerror(i32(err)))
		}
	}
	if err != os.ERROR_NONE {
		fmt.printfln("ERROR: Error saving to file `%s`: %s", filename, libc.strerror(i32(err)))
		return
	}
	// Set up file header
	fmt.fprintf(file, "P6\n%i %i\n255\n", canvas.width, canvas.height)
	for color in canvas.data {
		col: [3]byte = color.rgb
		_, err = os.write(file, col[:])
		if err != os.ERROR_NONE {
			fmt.printfln(
				"ERROR: Error writing to file `%s`: %s",
				filename,
				libc.strerror(i32(err)),
			)
		}
	}
	fmt.printfln("INFO: Succesfully saved canvas to %s", filename)
}

canvas_init :: proc(w, h: int, rect: ray.Rectangle) {
	app.canvas.width, app.canvas.height = w, h
	app.canvas.boundary = rect
	err: mem.Allocator_Error = nil
	app.canvas.data, err = make([]Color, w * h)
	mem.set(raw_data(app.canvas.data), 0xff, size_of(app.canvas.data[0]) * w * h)
	if err != nil {
		panic("Error initializing app.canvas")
	}
	ray.TraceLog(.INFO, "Initializing app.canvas")

	app.canvas.grid = ray.LoadRenderTexture(i32(rect.width), i32(rect.height))
	app.canvas.text = ray.LoadTextureFromImage(
		ray.Image {
			data = raw_data(app.canvas.data),
			width = c.int(app.canvas.width),
			height = c.int(app.canvas.height),
			mipmaps = 1,
			format = .UNCOMPRESSED_R8G8B8A8,
		},
	)

	ray.BeginTextureMode(app.canvas.grid)

	for x in 0 ..= w {
		rx := (f32(x) * rect.width) / f32(app.canvas.width)
		ray.DrawLineEx(ray.Vector2{rx, 0}, ray.Vector2{rx, rect.height}, 2, ray.BLACK)
	}
	for y in 0 ..= h {
		ry := (f32(y) * rect.height) / f32(app.canvas.height)
		// fmt.println(ry)
		ray.DrawLineEx(ray.Vector2{0, ry}, ray.Vector2{rect.width, ry}, 2, ray.BLACK)
	}

	ray.EndTextureMode()

}

canvas_destroy :: proc() {
	using app
	ray.UnloadRenderTexture(canvas.grid)
	ray.UnloadTexture(canvas.text)
	delete(canvas.data)
}

canvas_render :: proc() {
	using app
	ray.DrawTexturePro(
		canvas.text,
		ray.Rectangle{0, 0, f32(canvas.width), f32(canvas.height)},
		canvas.boundary,
		ray.Vector2{},
		0,
		ray.WHITE,
	)
	ray.DrawTextureV(
		canvas.grid.texture,
		ray.Vector2{canvas.boundary.x, canvas.boundary.y},
		ray.WHITE,
	)
}

canvas_update :: proc() {
	using app
	mouse_pos := ray.GetMousePosition()
	if ray.IsMouseButtonDown(.LEFT) && ray.CheckCollisionPointRec(mouse_pos, canvas.boundary) {
		rect_pos := mouse_pos - ray.Vector2{canvas.boundary.x, canvas.boundary.y}
		canvas_x := int(f32(canvas.width) * (rect_pos.x / canvas.boundary.width))
		canvas_y := int(f32(canvas.height) * (rect_pos.y / canvas.boundary.height))

		canvas.data[canvas_x + canvas_y * canvas.width] = active_color
	}
	ray.UpdateTexture(canvas.text, raw_data(canvas.data))
}

main :: proc() {
	// ray.SetConfigFlags(ray.ConfigFlags{.WINDOW_RESIZABLE})
	app.active_color = Color{0x00, 0xff, 0x00, 0xff}

	ray.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_TITLE)
	defer ray.CloseWindow()

	canvas_init(8, 8, ray.Rectangle{200, 0, 800, SCREEN_HEIGHT})
	defer canvas_destroy()

	ray.SetTargetFPS(60)
	can_draw: bool = true
	for !ray.WindowShouldClose() {
		screen_width, screen_height := ray.GetScreenWidth(), ray.GetScreenHeight()
		if can_draw {
			canvas_update()
		}

		ray.BeginDrawing()
		can_draw = !color_sliders({0, 0, 200, 150})
		ray.ClearBackground(COLOR_BACKGROUND)
		canvas_render()
		ray.EndDrawing()
	}
	canvas_save_ppm("out.ppm")

}
