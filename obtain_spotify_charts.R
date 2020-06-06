library(tidyverse)
library(lubridate)

###############################################################################################
##### SETUP SPOTIFY LOGIN #####################################################################

# Use `usethis::edit_r_environ()` ro edit your `.Renviron` and add the following two lines (without quotationmarks)

# "SPOTIFY_CLIENT_ID = <your_Spotify_client_id>"
# "SPOTIFY_CLIENT_SECRET = <your_Spotify_client_secret>"

# Further details: https://community.rstudio.com/t/how-to-set-a-variable-in-renviron/5029/3


###############################################################################################
##### IMPORT FUNCTIONS ########################################################################
# Import the functions defined in `download_functions.R`.
source("download_functions.R")


# Set the start date.
input_day <- today()

# Get the corresponding day of the week.
week_day <- wday(
  input_day,
  # Make sure weeks start on monday.
  week_start = getOption("lubridate.week.start", 1))

# Floor to the nearest monday.
ref_monday <- floor_date(
  input_day,
  unit = "week",
  # Make sure weeks start on monday.
  week_start = getOption("lubridate.week.start", 1))

# If `input_day` is any day of the week before friday, take the week before as as the final date.
final_date <- ifelse(
  week_day <= 4,
  ref_monday - 4,
  ref_monday + 3) %>% as_date()

# This is the earliest available chart reference date.
init_date <- ymd("2016-12-29")

# Create a vector from start to end with a step size of 7 days.
chart_ref_date <- seq(init_date, final_date, by = 7)

### DOWNLOAD THE WEEKLY CHARTS ###
# lapply: "List-Apply" (apply function to the elements of a list)
df <- lapply(chart_ref_date, download_spotify_charts_weekly) %>%
  # Bind the data frames into one, matching the columns by name.
  bind_rows()

### ADD THE UNAMBIGIOUS ISRC IDs ###
df <- df %>% 
  # Join with the ISRC IDs of the tracks. Use left join to force NAs in case of missing ISRC IDs.
  left_join(.,
            # Use unique internal IDs to reduce function calls.
            lapply(.$ID %>% unique, download_single_track_ISRC_ID) %>% 
              # Use `bind_rows()` to  stack the individual track information row-wise.
              bind_rows(),
            # Join on `ID` in df and `id` in the downloaded duration.
            by = c("ID" = "id"))

### ADD THE AUDIO FEATURES OF THE TRACKS ###
df <- df %>% 
  # Join with the ISRC IDs of the tracks. Use left join to force NAs in case of missing features.
  left_join(.,
            # Use unique internal IDs to reduce function calls.
            lapply(.$ID %>% unique, download_single_track_features) %>%
              # Use `bind_rows()` to  stack the individual track information row-wise.
              bind_rows(),
            by = c("ID" = "id"))

###############################################################################################
##### CHECK FOR CONSISTENCY ###################################################################
# If an error is provoked by this command, the data is inconsistent
df %>% pivot_wider(id_cols=ISRC_ID, names_from = Date, values_from = c(Position, Streams))

# Unify the artist and track names for a given track.
df <- df %>% 
  # Use `ISRC_ID` to indentify equal tracks.
  group_by(ISRC_ID) %>%
  # Take the artist name as the most frequent artist name in the group (probably obsolet).
  mutate(Artist = ifelse(all(is.na(Artist)),
                         NA,
                         names(which.max(table(Artist))))) %>%
  # Take the track name as the most frequent track name in the group.
  mutate(Track = ifelse(all(is.na(Artist)),
                        NA,
                        names(which.max(table(`Track Name`))))) %>%
  # Ungroup for further procesing.
  ungroup()

df <- df %>% 
  # Change the order of the columns and drop the original track name.
  select(Artist, Track, Position, Streams, Day, Month, Year, Week, Date, ID, everything(), -`Track Name`)

df %>% saveRDS(paste0(getwd(),"/Charts_fully_featured.Rds"))