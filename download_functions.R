library(dplyr)
library(spotifyr)
library(readr)
library(glue)

###############################################################################################
##### FUNCTIONS ###############################################################################

##### DOWNLOAD WEEKLY SPOTIFY CHARTS ##########################################################
download_spotify_charts_weekly <- function(ref_date) {
  # In the drop-down menu Spotify refers to `date`, but the link looks differently.
  url <- glue("https://spotifycharts.com/regional/de/weekly/{ref_date - 6}--{ref_date + 1}/download")
  
  # Skip the first row, as it contains the header.
  df <- read_csv(url, col_types = cols(
    Position = col_integer(), 
    Streams = col_integer()), skip = 1) %>% 
    mutate(Date = ref_date) %>%
    # Add a column for the day.
    mutate(Day = day(Date)) %>%
    # Add a column for the month.
    mutate(Month = month(Date)) %>% 
    # Add a column for the year.
    mutate(Year = year(Date)) %>%
    # Add a column for the week number.
    mutate(Week = week(Date)) %>% 
    # Convert the `URL` column to an `ID` column
    rename(ID = URL) %>% 
    mutate(ID = str_replace(ID, "https://open.spotify.com/track/", ""))
}

##### TRACKS ##################################################################################
# Download the information of a single track given by its track ID (TID).
download_single_track_features <- function(TID){
  TID %>% 
    get_track_audio_features() %>%
    select(
           # Danceability based on a combination of musical elements.
           danceability, 
           
           # A perceptual measure of intensity and activity.
           energy,
           
           # The key the track is in. Integers map to pitches using standard Pitch Class notation.
           key, 
           
           # The overall loudness of a track in decibels (dB).
           loudness,
           
           # Mode indicates the modality (major or minor) of a track.
           mode, 
           
           # Presence of spoken words in a track.
           speechiness,
           
           # A confidence measure whether the track is acoustic.
           acousticness,
           
           # Predicts whether a track contains no vocals.
           instrumentalness,
           
           # Probability that the track was performed live. 
           liveness,
           
           # Describing the musical positiveness conveyed by a track.
           valence,
           
           # The overall estimated tempo of a track in beats per minute (BPM).
           tempo, 
           
           id, 
           duration_ms)
}

# Download the external ISRC IDs for the tracks. This IDs is needed for filtering.
download_single_track_ISRC_ID <- function(TID) {
  get_track(TID) %>% {
    # Issue a message if the TID isn't available.
    if (is_null(.$external_ids$isrc)) {
      message(glue("Track with ID \"{TID}\" has been deleted from Spotify!\n",
                   "Using the internal ID \"TID: {TID}\" as a substitude for ISRC ID."))}
    
    # Use {...} notation to prevent the complete output to be piped as the first argument by default.
    {tibble(ISRC_ID = ifelse(is_null(.$external_ids$isrc),
                      # If the track isn't listed anymore, the only obtainable info is the artist ID.
                      glue("TID: {TID}"), 
                      .$external_ids$isrc),
            #Release = ymd(.$album$release_date), 
            id = .$id)}
  }
}