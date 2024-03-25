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


hslider :: proc(
	value: ^$T,
	min, max: T,
	boundary: ray.Rectangle,
	dragging: ^bool,
) where intrinsics.type_is_numeric(T) {
	valf := f32(value^)
	maxf := f32(max)
	minf := f32(min)
	start_pos := ray.Vector2{boundary.x + boundary.width / 8, boundary.y + boundary.height / 2}
	end_pos := ray.Vector2{boundary.x + boundary.width / 8 * 7, boundary.y + boundary.height / 2}
	ray.DrawLineEx(start_pos, end_pos, boundary.height / 2, COLOR_SLIDER)

	// (value / (max - min)) * (start_pos.x - end_pos.x) 

	selector_center := ray.Vector2 {
		(end_pos.x - start_pos.x) * valf / (maxf - minf) + start_pos.x,
		start_pos.y,
	}

	ray.DrawCircleV(selector_center, boundary.height / 1.8, COLOR_SLIDER_SELECTOR)

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
	dragging: [3]bool

	ray.SetTargetFPS(60)
	for !ray.WindowShouldClose() {
		canvas_update()

		ray.BeginDrawing()
		ray.ClearBackground(ray.RAYWHITE)
		canvas_render()
		hslider(&(app.active_color.r), 0, 255, Rectangle{0, 20, 200, 20}, &dragging.r)
		hslider(&(app.active_color.g), 0, 255, Rectangle{0, 60, 200, 20}, &dragging.g)
		hslider(&(app.active_color.b), 0, 255, Rectangle{0, 100, 200, 20}, &dragging.b)
		ray.EndDrawing()
	}
	canvas_save_ppm("out.ppm")

}
