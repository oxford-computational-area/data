# system()

system(command = "ls")
current_dir <- system(command = "pwd", intern = TRUE)
current_dir

library(stringr)
message <- "hello there"
command <- str_glue("echo {message}")
system(command)

# Install R packages
# Assuming tidyverse, av, magick et al are already installed
install.packages(c("colorfindr", "farver", "googleCloudVisionR"))

# Image convert
library(magick)
image_read("image.png") |>
  image_write("image.jpg", format = "jpeg")

# Inspect
library(tidyverse)
library(av)
library(magick)

fileinfo_is <- file.info("martyr_is.mp4")
fileinfo_is$size / 1000000 # 54MB

fileinfo_sdf <- file.info("martyr_sdf.mp4")
fileinfo_sdf$size / 1000000 # 76MB

mediainfo_is <- av_media_info("martyr_is.mp4")
mediainfo_is$duration / 60 # 4.7 mins

mediainfo_sdf <- av_media_info("martyr_sdf.mp4")
mediainfo_sdf$duration / 60 # 4.3 mins

# Get frames
# How many frames available?
mediainfo_is$video$frames # 6809
mediainfo_sdf$video$frames # 6655

# Create dirs to keep them
dir.create("frames_is")
dir.create("frames_sdf")

# Get one frame every 5 seconds
av_video_images("martyr_is.mp4", destdir = "frames_is", fps = 0.2)
frames_is <- list.files("frames_is", full.names = TRUE)
length(frames_is) # 57

av_video_images("martyr_sdf.mp4", destdir = "frames_sdf", fps = 0.2)
frames_sdf <- list.files("frames_sdf", full.names = TRUE)
length(frames_sdf) # 53

# View frames in montage
image_read(frames_is) |>
  image_montage(tile = "9", geometry = "x150") |>
  image_write("frames_is.jpg", format = "jpg")

image_read(frames_sdf) |>
  image_montage(tile = "9", geometry = "x150") |>
  image_write("frames_sdf.jpg", format = "jpg")

# Get scenes

# Create dirs to keep scenes
dir.create("scenes_is")
dir.create("scenes_sdf")

# Extract scenes
system("scenedetect -i martyr_is.mp4 -o scenes_is save-images -n 1 -f is_\\$SCENE_NUMBER")
system("scenedetect -i martyr_sdf.mp4 -o scenes_sdf save-images -n 1 -f sdf_\\$SCENE_NUMBER")

# View scenes in montage

# Create vectors with paths to the scene files
scenes_is <- list.files(
  "scenes_is",
  full.names = TRUE
)

scenes_sdf <- list.files(
  "scenes_sdf",
  full.names = TRUE
)

# Inspect
length(scenes_is) # 48
length(scenes_sdf) # 67

# Make montages
image_read(scenes_is) |>
  image_montage(tile = "8", geometry = "x150") |>
  image_write("scenes_is.jpg", format = "jpg")

image_read(scenes_sdf) |>
  image_montage(tile = "8", geometry = "x150") |>
  image_write("scenes_sdf.jpg", format = "jpg")

# Colours

library(colorfindr)
library(farver)

# View example image
browseURL(scenes_sdf[51])

# Quantize with magick functions
image_read(scenes_sdf[51]) |>
  image_quantize(max = 24, colorspace = "sRGB") |>
  image_write("temp.jpg", format = "jpg")

# View quantized image
browseURL("temp.jpg")

# View colours
df_col <- get_colors("temp.jpg", top_n = 24)
plot_colors(df_col, sort = "size")

# Color diversity

plot_colors_3d(
  df_col,
  sample_size = 1000,
  marker_size = 10,
  color_space = "RGB"
)

# Convert hex to numeric RGB values
rgb_cols <- decode_colour(df_col$col_hex)

# Convert RGB to CIE Lab
lab_cols <- convert_colour(
  rgb_cols,
  from = "rgb",
  to = "lab"
)

# Sum up distances
sum(dist(lab_cols))

# Brightness

# load image
img <- image_read(scenes_sdf[51])

# convert to grayscale
img_gray <- image_convert(img, colorspace = "gray")

# calculate average brightness of all pixels
img_data <- as.numeric(img_gray[[1]])
mean(img_data) # 0.45

# Compare montages

# Create montages with no white tiles
length(frames_is) # 57
length(frames_sdf) # 53

image_read(frames_is) |>
  image_montage(tile = "19", geometry = "x150") |>
  image_write("frames_is_no_white.jpg", format = "jpg")

image_read(frames_sdf[2:53]) |> # drop first img to get divisable number
  image_montage(tile = "13", geometry = "x150") |>
  image_write("frames_sdf_no_white.jpg", format = "jpg")

# Quantize
image_read("frames_is_no_white.jpg") |>
  image_quantize(max = 24, colorspace = "sRGB") |>
  image_write("temp1.jpg", format = "jpg")

image_read("frames_sdf_no_white.jpg") |>
  image_quantize(max = 24, colorspace = "sRGB") |>
  image_write("temp2.jpg", format = "jpg")

# View colours
df_col1 <- get_colors("temp1.jpg", top_n = 24)
plot_colors(df_col1, sort = "size")

df_col2 <- get_colors("temp2.jpg", top_n = 24)
plot_colors(df_col2, sort = "size")

# Compare color diversity
plot_colors_3d(
  df_col1,
  sample_size = 1000,
  marker_size = 10,
  color_space = "RGB"
)

plot_colors_3d(
  df_col2,
  sample_size = 1000,
  marker_size = 10,
  color_space = "RGB"
)

# Aggregate distance IS
decode_colour(df_col1$col_hex) |>
  convert_colour(from = "rgb", to = "lab") |>
  dist() |>
  sum() # 9558

# Aggregate distance SDF
decode_colour(df_col2$col_hex) |>
  convert_colour(from = "rgb", to = "lab") |>
  dist() |>
  sum() # 12376

# Comparing brightness
# IS images
img_gray1 <- image_read("frames_is_no_white.jpg") |>
  image_convert(colorspace = "gray")

img_data1 <- as.numeric(img_gray1[[1]])
mean(img_data1) # 0.27

# SDF images
img_gray2 <- image_read("frames_sdf_no_white.jpg") |>
  image_convert(colorspace = "gray")

img_data2 <- as.numeric(img_gray2[[1]])
mean(img_data2) # 0.40


# Google Vision

library(googleCloudVisionR)

preds <- gcv_get_image_annotations(
  imagePaths = "scenes_sdf/sdf_014.jpg",
  feature = "LABEL_DETECTION",
  maxNumResults = 7
)

preds$description # labels
preds$score # confidence
preds$topicality # prominence

preds <- gcv_get_image_annotations(
  imagePaths = "scenes_sdf/sdf_019.jpg",
  feature = "FACE_DETECTION",
  maxNumResults = 7
)

str(preds)

# Rclip
results <- system(intern = TRUE, "cd scenes_sdf && rclip -nf horse")
browseURL(results[1])

results <- system(intern = TRUE, "cd scenes_sdf && rclip -f woman")
browseURL(results[1])

results <- system(intern = TRUE, "cd scenes_sdf && rclip -nf winter")
browseURL(results[3])
