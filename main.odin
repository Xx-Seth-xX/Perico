package main

import ray "vendor:raylib"
import "core:fmt"
import "core:c"
import "core:mem"

SCREEN_WIDTH :: 1000
SCREEN_HEIGHT :: 800
SCREEN_TITLE :: "Perico"

Canvas :: struct {
    data : []ray.Color,
    width, height: int,
    screen_rect: ray.Rectangle,
    text: ray.Texture2D,
    grid: ray.RenderTexture2D
}

canvas_init :: proc (w, h: int, rect: ray.Rectangle) -> Canvas{
    canvas := Canvas{}
    canvas.width, canvas.height = w, h
    canvas.screen_rect = rect
    err : mem.Allocator_Error = nil
    canvas.data, err = make([]ray.Color, w * h)
    if err != nil {
        panic("Error initializing canvas")
    }
    ray.TraceLog(.INFO, "Initializing canvas")

    canvas.grid = ray.LoadRenderTexture(i32(rect.width), i32(rect.height))
    canvas.text = ray.LoadTextureFromImage(ray.Image{
        data = raw_data(canvas.data),
        width = c.int(canvas.width),
        height = c.int(canvas.height),
        mipmaps = 1,
        format = .UNCOMPRESSED_R8G8B8A8, 
    })

    ray.BeginTextureMode(canvas.grid)

    for x in 0 ..=w {
        rx := (f32(x) * rect.width) / f32(canvas.width)
        ray.DrawLineEx(ray.Vector2{rx, 0}, ray.Vector2{rx, rect.height}, 2, ray.BLACK)
    }
    for y in 0 ..=h {
        ry := (f32(y) * rect.height) / f32(canvas.height)
        // fmt.println(ry)
        ray.DrawLineEx(ray.Vector2{0, ry}, ray.Vector2{rect.width, ry}, 2, ray.BLACK)
    }

    ray.EndTextureMode()

    return canvas
}

canvas_destroy :: proc (using canvas: ^Canvas) {
    ray.UnloadRenderTexture(grid)
    ray.UnloadTexture(text)
    delete(data)
}

canvas_render :: proc (using canvas: ^Canvas) {
    ray.DrawTexturePro(text, ray.Rectangle{0, 0, f32(width), f32(height)}, screen_rect, ray.Vector2{}, 0, ray.WHITE)
    ray.DrawTextureV(grid.texture, ray.Vector2{screen_rect.x, screen_rect.y}, ray.WHITE)
}

canvas_update :: proc(using canvas: ^Canvas) {
    mouse_pos := ray.GetMousePosition()
    if ray.IsMouseButtonDown(.LEFT) && ray.CheckCollisionPointRec(mouse_pos, screen_rect){
        rect_pos := mouse_pos - ray.Vector2{screen_rect.x, screen_rect.y} 
        canvas_x := int(f32(width) * (rect_pos.x / screen_rect.width))
        canvas_y := int(f32(height) * (rect_pos.y / screen_rect.height))

        data[canvas_x + canvas_y * width] = ray.Color{0x00, 0x00,0x00,  0xff}
        // fmt.println(canvas_x, canvas_y)
    }
    ray.UpdateTexture(text, raw_data(data))
}

main :: proc () {
    // ray.SetConfigFlags(ray.ConfigFlags{.WINDOW_RESIZABLE})

    ray.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_TITLE)
    defer ray.CloseWindow()

    canvas := canvas_init(8, 8, ray.Rectangle{200, 0, 800, SCREEN_HEIGHT})
    defer canvas_destroy(&canvas)
    
    for !ray.WindowShouldClose() {
        canvas_update(&canvas)
      
        ray.BeginDrawing()
        ray.ClearBackground(ray.RAYWHITE)
        canvas_render(&canvas)
        ray.EndDrawing()
    }
    
}



