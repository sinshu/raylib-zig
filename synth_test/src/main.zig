const std = @import("std");
const rl = @import("raylib");
const ziggysynth = @import("ziggysynth.zig");
const debug = std.debug;
const fs = std.fs;
const heap = std.heap;
const mem = std.mem;
const Allocator = mem.Allocator;
const SoundFont = ziggysynth.SoundFont;
const Synthesizer = ziggysynth.Synthesizer;
const SynthesizerSettings = ziggysynth.SynthesizerSettings;
const MidiFile = ziggysynth.MidiFile;
const MidiFileSequencer = ziggysynth.MidiFileSequencer;

const sample_rate = 44100;
const buffer_size = 2048;

pub fn main() anyerror!void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer debug.assert(!gpa.deinit());

    rl.InitWindow(800, 450, "MIDI Player");

    rl.InitAudioDevice();
    rl.SetAudioStreamBufferSizeDefault(buffer_size);

    var stream = rl.LoadAudioStream(sample_rate, 16, 2);
    var left: [buffer_size]f32 = undefined;
    var right: [buffer_size]f32 = undefined;
    var buffer: [2 * buffer_size]i16 = undefined;

    rl.PlayAudioStream(stream);

    // Load the SoundFont.
    var sf2 = try fs.cwd().openFile("TimGM6mb.sf2", .{});
    defer sf2.close();
    var sound_font = try SoundFont.init(allocator, sf2.reader());
    defer sound_font.deinit();

    // Create the synthesizer.
    var settings = SynthesizerSettings.init(44100);
    var synthesizer = try Synthesizer.init(allocator, sound_font, settings);
    defer synthesizer.deinit();

    // Load the MIDI file.
    var mid = try fs.cwd().openFile("flourish.mid", .{});
    defer mid.close();
    var midi_file = try MidiFile.init(allocator, mid.reader());
    defer midi_file.deinit();

    // Create the sequencer.
    var sequencer = try MidiFileSequencer.init(allocator, synthesizer);
    defer sequencer.deinit();

    // Play the MIDI file.
    sequencer.play(midi_file, true);

    var speed_x10: i32 = 10;
    var speed_str_buf: [64]u8 = undefined;

    rl.SetTargetFPS(60);

    var left_level: f32 = 0.0;
    var right_level: f32 = 0.0;

    while (!rl.WindowShouldClose()) {

        if (rl.IsKeyPressed(rl.KeyboardKey.KEY_LEFT)){
            speed_x10 -= 1;
            if (speed_x10 < 1) {
                speed_x10 = 1;
            }
        }

        if (rl.IsKeyPressed(rl.KeyboardKey.KEY_RIGHT)){
            speed_x10 += 1;
            if (speed_x10 > 100) {
                speed_x10 = 100;
            }
        }

        const speed = @intToFloat(f64, speed_x10) / 10.0;
        speed_str_buf = mem.zeroes([64]u8);
        const speed_str_slice = try std.fmt.bufPrint(&speed_str_buf, "x{d:.1}", .{speed});

        sequencer.speed = speed;

        if (rl.IsAudioStreamProcessed(stream)) {
            sequencer.render(&left, &right);
            var t: usize = 0;
            var left_max: f32 = 0.0;
            var right_max: f32 = 0.0;
            while (t < buffer_size) : (t += 1) {
                var left_sample_i32: i32 = @floatToInt(i32, 32768.0 * left[t]);
                if (left_sample_i32 < -32768) {
                    left_sample_i32 = -32768;
                }
                if (left_sample_i32 > 32767) {
                    left_sample_i32 = 32767;
                }
                if (left[t] > left_max) {
                    left_max = left[t];
                }
                var right_sample_i32: i32 = @floatToInt(i32, 32768.0 * right[t]);
                if (right_sample_i32 < -32768) {
                    right_sample_i32 = -32768;
                }
                if (right_sample_i32 > 32767) {
                    right_sample_i32 = 32767;
                }
                if (right[t] > right_max) {
                    right_max = right[t];
                }
                var left_sample_i16 = @truncate(i16, left_sample_i32);
                var right_sample_i16 = @truncate(i16, right_sample_i32);
                buffer[2 * t] = left_sample_i16;
                buffer[2 * t + 1] = right_sample_i16;
            }
            rl.UpdateAudioStream(stream, &buffer, buffer_size);
            left_level = left_max;
            right_level = right_max;
        }

        rl.BeginDrawing();
        rl.ClearBackground(rl.LIGHTGRAY);
        rl.DrawText("Playback", 140, 155, 50, rl.DARKGRAY);
        rl.DrawText("speed", 140, 205, 50, rl.DARKGRAY);
        rl.DrawText(@ptrCast(*const u8, speed_str_slice), 400, 130, 150, rl.DARKGRAY);
        rl.DrawRectangle(140, 270, @floatToInt(i32, 600.0 * left_level), 15, rl.GRAY);
        rl.DrawRectangle(140, 285, @floatToInt(i32, 600.0 * right_level), 15, rl.GRAY);
        rl.EndDrawing();
    }

    rl.CloseWindow();
}
