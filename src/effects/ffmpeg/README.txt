----------

About

----------

This is short info on FFmpeg Video Filter and its syntax in .txt format for OpenShotWYH


----------

Video Filter


----------

OpenShotWYH's Video Filter
is FFmpeg graph based video filter for static images (applies per RGBA frame).
Mainly designed for a bit more advanced color correction of the footage in the editor.
As for now filter applies to full frame only.


----------

Text files of the filters

----------

Each filter description file has ".txt" extention and consist of few strings ended by newline.
All rows (5) should present in the file (some may be empty).

First row
Version of the file description.
Field can be: "v1", "v2" (without quotes)

Second row
User friendly name of the filter.
Field can be: Any suitable string. Short sting is welcomed.

Third row
Comment string.
Field can be: Any suitable string. Place here info about the filter itself. Can be empty string.

Forth row
Filter description string that follows FFmpeg graph description rules in the text format.
For syntax details see: https://ffmpeg.org/ffmpeg-filters.html#Filtergraph-description
Each description string has build-in preceding string: "sws_flags=bicubic+accurate_rnd+full_chroma_int; buffer=video_size=1280x720:pix_fmt=26:time_base=1/25:pixel_aspect=1/1 ",
where 1280x720 is actual size of the input image. Input buffer filled with RGBA image, full color range, pts always 0.
For previews the "sws_flags=bicubic" replaced by "sws_flags=fast_bilinear". For the filter friendly name "debug" the "+print_info" flag will be added to the "sws_flags="
For filter file version "v2" the "P_1", "P_2", "P_3", "P_4" text in the filter description will be replaced by the current float values of the corresponding Keyframes from the OpenShotWYH program.
Special characters for the file paths (backslash, colon, space etc.) should be escaped with the "\" (backslash).
The full path for Windows OS may look like this: C\\:\\\\Temp\\\\ffmpeg_clut_rgba_my_adjustments.png
Field can be: Any valid FFmpeg filtergraph-description string.

Fifth row
Reserved for arguments string. Feature not implemented.
Field can be: Any string. Can be empty string.


----------

End

----------