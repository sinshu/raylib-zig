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
const buffer_size = 4096;

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
    sequencer.play(midi_file, false);

    rl.SetTargetFPS(60);

    while (!rl.WindowShouldClose()) {

        if (rl.IsAudioStreamProcessed(stream)) {
            sequencer.render(&left, &right);
            var t: usize = 0;
            while (t < buffer_size) : (t += 1) {
                var left_sample_i32: i32 = @floatToInt(i32, 32768.0 * left[t]);
                if (left_sample_i32 < -32768) {
                    left_sample_i32 = -32768;
                }
                if (left_sample_i32 > 32767) {
                    left_sample_i32 = 32767;
                }
                var right_sample_i32: i32 = @floatToInt(i32, 32768.0 * right[t]);
                if (right_sample_i32 < -32768) {
                    right_sample_i32 = -32768;
                }
                if (right_sample_i32 > 32767) {
                    right_sample_i32 = 32767;
                }
                var left_sample_i16 = @truncate(i16, left_sample_i32);
                var right_sample_i16 = @truncate(i16, right_sample_i32);
                buffer[2 * t] = left_sample_i16;
                buffer[2 * t + 1] = right_sample_i16;
            }
            rl.UpdateAudioStream(stream, &buffer, buffer_size);
        }

        rl.BeginDrawing();
        rl.ClearBackground(rl.WHITE);
        rl.DrawText("Congrats! You created your first window!", 190, 200, 20, rl.LIGHTGRAY);
        rl.EndDrawing();
    }

    rl.CloseWindow();
}
