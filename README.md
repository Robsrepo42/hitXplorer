# Hit Xplorer
all files needed to view and execute a shiny app xploring spotify chart data by using the RStudio IDE.

# Background
This is a project that was part of an assignment at the University of Applied Sciences in Kiel, more specifically being a part of a Data Science program and a course for Data Visualisation and Visual Analytics.

# The Task 
Develop a shiny app that allows a user to explore your data interactively. 
The shiny app should contain one or more plots, but it may also contain other elements, such as data or text.
Make deliberate decisions about both the content and the design of your shiny app. 
While it may be technically possible to make any aspect of your app customizable, this might overwhelm the user, or it might lead to unfavorable visualizations (e.g. bar charts with 1000 bars). Therefore, whatever you do, consider the user experience. 
Include also a Readme.md file in which you shortly summarise your project (data source, variable definition, data cleaning/transformation, purpose of your app, etc.) and explain technical aspects of your app (features that you used or things that you learned about shiny). 

# Our Approach, i.e. the idea for our webapp:
Spotify is one of the world‘s most popular online music services, where millions of users stream billions of songs every year. Spotify makes the 200 most popular songs available at spotifycharts.com for different regions (i.e. countries) per day and per week. Shows and Stations playing Chart-Hit-Music are capitalizing on the popularity of these songs. 

*Where does charting hit music come from and where does it go after reaching the top?*

*Is popularity of a song gained over longer periods and kept for longer periods? Or are the charts a „Hit and Run“- Business? (excuse the pun)*

*Are there patterns in Hit-Music-Evolution (worth exploring) further?*

# Obtaining the Data from Spotify
We chose to go for weekly top 200 charts from Germany. This Data is available back to 12/29/2016, i.e. the last week of 2016, thus currently dating back ~178 weeks. We wanted to be able to download the spotify charts data by creating a download function that:

*Takes a given date (like „today()“)*
*Turns this into the nearest (weekly) chart publication date*
*Which then becomes the last entry in a date vector that includes all consecutive publication dates since 12/29/2016*
*Which is then applied via the “lapply = list apply“ function to a glued together download URL*
*And appends every new chart table to the one before together with that particular weeks date to create one large data set with more than 10 thousand observations*

The resulting download function code can be found in this repo, but it didn't leave us with clean and tidy data. The reason for this being that the data comes with 5 variables (position, track, artist, streams, URL), but unfortunately none of these are unique.

Some of the problems we ran into can be illustrated by the following examples:
![Shawn Mendes](https://github.com/Robsrepo42/hitXplorer/blob/master/Screenshots/Shawn%20Mendes%20-%20Senorita.png)
In this example it can be seen that the song ID changes for no apparent reason. One approach to eliminate these additional song IDs was to use the song's length as an additional identifier. In the case of Shawn Mendes it turned out that another one of this artists songs (If I Can't Have You) has exactly the same song length. The problem was eventually solved by querying the ISRC from spotify (see below).

![Apache](https://github.com/Robsrepo42/hitXplorer/blob/master/Screenshots/Apache%20207.png)

This example shows that a song with the same ISRC ID can actually have different lengths. It was not possible to clear up the difference between these two spotify IDs of the same song with a length difference of 933 miliseconds.

The lack of a unique identifier gave us headaches and messy visuals zigzaging all over the place. We needed to query spotify's REST API via the R package "spotifyr", which is not available via CRAN anymore (but can be downloaded elsewhere, thank you Charlie!)

## Spotify REST API
We generated Spotify Developer IDs. Among the ~45 API Call Functions we found get_track(„URI“), which delivers (among others):
$external_ids$isrc. The ISRC: International Standard Recording Code was finally able to serve us as a unique ID for all songs in our data set. Since we could now do API-Calls on song IDs, we also amended our data set with each songs audio features (i.e. scores on danceability, valence... etc.), since we thought that this data might be helpful for later steps in analysis. 

However our data turned out to be still not entirely clean… as some songs seem have been partially deleted by spotify (or the artists labels?) This means that the chart entry of an artists is still there, but the artists itself can't be queried. Fortunately the number of deleted artists was not large and did not influence the results.

# Firt Visual Impressions / Data Exploration
Looking „forward“ towards the selected „Chart Week“ we identified at least three different patterns:

**„Instant Glory“** for songs that basically started at the top. These releases might be long expected events which induce a large and loyal fan base to massive listening as soon as the record drops

**“Earned Fame“** for songs that rose to the top and stayed up there in a process that took a number of weeks

**“Fast Lane“** for songs that made it to the top from the bottom fast, but not instantly (as the group above), but it also did‘t take them as long as the "earners"

## Non-Starters and Beyond-Scopers vs. Final Shiny App Features
Observing different patterns made us investigate top charting artists further. It turned out that significant “chart shares“ went to German rap artists (e.g.  Apache 207, Kollegah etc.). This created the hypothesis, that these artists might not get a lot of exposure in mainstream audio media due to the explicit content, which forced their loyal niche audience to extensively use Spotify for music consumption. 

We then investigated if we could exclude certain genres from our analysis, to be able to correct for this skew and focus analysis more on generally popular music. It turned out that artists are assigned multiple genres by Spotify and this approach is beyond scope for this project - but might well be an interesting feature for a future edition of this app.

We briefly thought about a cluster analysis of the audio features, thereby assigning something like our own genres, but resolved this as limited by time and scope of the project, as well.

# Final Shiny App
In this first release we would wanted to give the user the following interactive capabilities for visual data exploration:

*Let the user pick start and end dates within our data time-frame*

*Let the user define the week in which to fix the chart positions*

*Let the user decide whether he/she wants to look at top 10/20/30/40 chart positions*

*Let the user decide whether he/she wants to observe positions or the number of streams necessary to obtain that chart position in a particular week*

And then deliver a visual „Evolution of Chart Hit Music“ from the set start date through the fixed chart week and beyond towards the chosen end date.

# Executing the code in this repository
You can generate an updated data file yourself by using the download R skript. The faster approach to a first glimpse at the app would be to download the App.R Skript and execute it. The code will call our datafile in the repository which is dated from the beginning of June 2020. If you want more current / latest data - you will have to go through the download functions.

We hope you enjoy and possibly amend this work.

