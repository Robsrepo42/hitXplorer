library(shiny)
library(tidyverse)
library(lubridate)
library(plotly)
library(glue)
library(shinyCustom)

# Make the sliders work better.
useShinyCustom(slider_policy = "debounce", slider_delay = "250")

df <- readRDS(url("https://github.com/Robsrepo42/hitXplorer/raw/master/Charts_fully_featured.Rds"))

feature_df <- df %>% 
  # Pivot all columns from `danceability` to `duration_ms`
  pivot_longer(danceability:duration_ms, names_to = "Features", values_to = "Values")

first_date <- min(df$Date)
last_date <- max(df$Date)

# Anything you put inside this function ends up in the app.
ui <- fluidPage(
  # Use a bit of java script to obtain the window width and heigth.
  # Source: https://stackoverflow.com/questions/44324783/dynamically-adjust-height-and-or-width-of-shiny-plotly-output-based-on-window-si
  tags$head(tags$script('
                        var dimension = [0, 0];
                        $(document).on("shiny:connected", function(e) {
                        dimension[0] = window.innerWidth;
                        dimension[1] = window.innerHeight - 
                        document.getElementsByClassName(\'row\').item(0).offsetHeight;
                        Shiny.onInputChange("dimension", dimension);
                        });
                        $(window).resize(function(e) {
                        dimension[0] = window.innerWidth;
                        dimension[1] = window.innerHeight - 
                        document.getElementsByClassName(\'row\').item(0).offsetHeight;
                        Shiny.onInputChange("dimension", dimension);
                        });
                        ')),
  
  # Get inputs from the user using *Input() functions.

  # fliudRow layout with input definitions.
  fluidRow(
      
    # Column for date inputs (padding of 3% seems appropriate).
    column(width = 4, style="padding-left:3%; padding-right:3%;",
      # Input: Specification of date range within an interval.
      customSliderInput(inputId = "obs_range",
                  label = "Select the Range of Dates",
                  min = first_date, max = last_date,
                  value = range(df$Date), step = days(7),
                  ticks = FALSE),
      
      # Input: Specification of reference date.
      customSliderInput(inputId = "ref_date",
                  label = "Choose a Reference Date",
                  min = first_date, max = last_date,
                  value = first_date, step = days(7), 
                  ticks = FALSE)
    ),
    # Column for track and position inputs (padding of 3% seems appropriate)
    column(width = 4, style="padding-left:3%; padding-right:3%;",
      # Input: Specification of number of tracks.
      customSliderInput(inputId = "track_nums",
                  label = "Choose the Number of Tracks",
                  min = 1L, max = 20L,
                  value = 10L, step = 1L, 
                  ticks = FALSE),
      
      # Input: Specification of range of tracks.
      customSliderInput(inputId = "pos_range",
                  label = "Select the Range of Positions",
                  min = 1L, max = 200L,
                  value = c(1L, 10L), step = 1L, 
                  ticks = FALSE)
    ),
    # Column for display variable input (padding of 3% seems appropriate)
    column(width = 4, style="padding-left:3%; padding-right:3%;",
      # Input: Specification of variable to display.
      radioButtons(inputId = "pos_vs_streams",
                   label = "Variable on the Main Plot's Y-Axis",
                   # Names displayed to the user.
                   choices = c("Position", "Streams"),
                   # # Corresponding values for internal use.
                   # choiceValues = c("Position", "Streams"),
                   selected = "Position"),
      
      # Input: Specification of period of background data for box and wiskers plot.
      radioButtons(inputId = "background_ref",
                   label = "Backgorund Period for Features",
                   # Names displayed to the user.
                   choices = c("Week", "Month", "Year", "All"),
                   # # Corresponding values for internal use.
                   # choiceValues = c("Position", "Streams"),
                   selected = "Week")
    )
  ),
  
  hr(),
  tabsetPanel(
    # Output Panel 1:
    tabPanel("Main", plotlyOutput(outputId = "main")),
    tabPanel("Features", plotlyOutput(outputId = "features"))
  )
)

# Use the server function to assemble inputs and outputs.
server <- function(input, output, session) {
  # Rules:
  # 1. Save objects to display as output$<outputId> <- ...
  # 2. What is saved as an output must be created using a render*() function.
  #    You can use braces to define a code block of mutliple lines.
  # 3. Use input values with input$<inputId>
  
  # Build outputs in the server function
  # The render*() functions convert the argument to HTML and keep track of the reactions of the user.
  
  ### OBSERVING USER ACTIONS
  # An observer is like a reactive expression, but does not yield any result.
  # Observe only changes in `input$obs_range` here to change the `ref_date` slider accordingly.
  observeEvent(input$obs_range, 
               {
                 # `input$obs_range` is a two element vector reactive.
                 obs_range <- input$obs_range
                 
                 # Obtain a new value for `ref_date` in case it is out of `obs_range`.
                 new_ref_date <- function(date) {
                   if (date < min(obs_range)) {
                     date <- min(obs_range)
                   } else if (date > max(obs_range)) {
                     date <- max(obs_range)
                   }
                   return(date)
                 }
                 
                 # Update the second slider based on the input of the first slider.
                 updateSliderInput(session, inputId = "ref_date",
                                   min = min(obs_range), max = max(obs_range),
                                   value = new_ref_date(input$ref_date))
               })
  
  # Observe only changes in `input$track_nums` here to change the `pos_range` slider accordingly.
  observeEvent(input$track_nums,
               {
                 # Prevent changes in `pos_range` to invalidate this `observeEvent` reactive.
                 min_pos <- isolate(min(input$pos_range))
                 max_pos <- isolate(max(input$pos_range))
                 
                 # Update the maximum of `pos_range` as long as `pos_range` remains valid.
                 if (min_pos + input$track_nums  <= 200L) {
                   updateSliderInput(session, inputId = "pos_range",
                                     value = c(min_pos, min_pos + input$track_nums - 1))
                   
                 } else {
                   updateSliderInput(session, inputId = "pos_range",
                                     value = c(200L - input$track_nums + 1, 200L))
                 }
                 
               })
  
  # Define the `pos_range_vals` reactiveValues.
  prev_pos_range <- reactiveValues(
    min = isolate(min(input$pos_range)),
    max = isolate(max(input$pos_range))
    )
  
  # Observe only changes in `input$track_nums` here to change the `pos_range` or `track_nums` slider accordingly.
  observeEvent(input$pos_range, {
    # Obtain the new positons of the sliders AFTER a change in `pos_range` occured.
    curr_pos_range <- list(min = isolate(min(input$pos_range)),
                           max = isolate(max(input$pos_range)))
    
    # The minimum has been updated, move the maximum slider accordingly or adjust `input$track_nums`.
    if (prev_pos_range$min != curr_pos_range$min) {
      new_max <- isolate(curr_pos_range$min + input$track_nums - 1)
      # Update the `input$track_nums`
      if (new_max > 200L) {
        updateSliderInput(session, inputId = "track_nums",
                          # Set the value to match `input$pos_range`.
                          value = 200L - curr_pos_range$min + 1)
      }
      # Update the maximum slider of `input$pos_range` and ...
      # ... set the new value for `prev_pos_range$max`.
      # The latter is very important as the update will trigger this observer again.
      else {
        updateSliderInput(session, inputId = "pos_range",
                          value = c(curr_pos_range$min, new_max))
        # Update the reactiveValues. Use braces ({...}) to update both values simultaneously (neccessary?).
        {prev_pos_range$min = curr_pos_range$min
         prev_pos_range$max = new_max}
      }
    } 
    # The maximum has been updated, move the minimum slider accordingly or adjust `input$track_nums`.
    else if (prev_pos_range$max != curr_pos_range$max) {
      new_min <- isolate(curr_pos_range$max - input$track_nums + 1)
      # Update the `input$track_nums`
      if (new_min < 1L) {
        updateSliderInput(session, inputId = "track_nums",
                          value = curr_pos_range$max)
      }
      # Update the minimum slider of `input$pos_range` and ...
      # ... set the new value for `prev_pos_range$min`.
      # The latter is very important as the update will trigger this observer again.
      else {
        updateSliderInput(session, inputId = "pos_range",
                          value = c(new_min, curr_pos_range$max))
        # Update the reactiveValues. Use braces ({...}) to update both values simultaneously (neccessary?).
        {prev_pos_range$min = new_min
         prev_pos_range$max = curr_pos_range$max}
      }
    }
  })
  
  ### MAIN PLOT
  # All `input$...` variables are reactive sources and can be simply used in reactive environments.
  # Use braces {...} to create a block which finally yields a plotly.  
  output$main <- renderPlotly({
    # Obtain the `Position` and `ISRC_ID` of the tracks within the `topx` and `ref_date`.
    ID_pos <- df %>%
      filter(Date == input$ref_date & Position >= prev_pos_range$min & Position <= prev_pos_range$max) %>% 
      select(Position, ISRC_ID)
    
    # Select the desired tracks use the `ID_pos` reactive as a filter. 
    p <- df %>%
      # Use a `üivot_wider to introduce NAs.
      pivot_wider(id_cols = c(Artist, Track, ISRC_ID), names_from = Date, values_from = c(Position, Streams)) %>% 
      # Pivot the columns starting with`Position_...` and `Streams_...` into a longer format.
      # Separate the individual column names by `names_sep = "_"`.
      # The former part plays to role of `values_to = ...` as indicated by the keyword `.value`.
      # The latter part is written to the column `Date`.
      # Note that there would be actually two redundant `Date` columns (one from "Position_..." and "Stream_", respectively)
      # The function seems to automatically handle these redundant `Date` calumns making them unique.
      # (https://community.rstudio.com/t/pivot-longer-on-multiple-column-sets-pairs/43958/10)
      pivot_longer(cols = c(starts_with("Position_"), starts_with("Streams_")),
                   names_to = c(".value", "Date"), names_sep = "_") %>% 
      # The `Date` column created by `pivot_longer(...)` is of type <chr>, but needs to be numeric.
      mutate(Date = ymd(Date)) %>% 
      filter(ISRC_ID %in% {ID_pos %>% pull(ISRC_ID)}) %>%
      group_by(ISRC_ID) %>% 
      # Get the Postion at `input$ref_date`
      # As stated in `?groupy_by`: "It changes how it acts with the other dplyr verbs"
      # To make use of that everything related to the individual group it has to be inside a dplyr verb.
      mutate(Ref_Position = {
        # Obtain the ISRC_ID for each group individually. (This is not possible outside of this scope!)
        grouping_ISRC <- unique(ISRC_ID)
        # Obtain the `Position` at `ref_date` from `ID_pos`.
        ref_pos <- grouping_ISRC %>%  
          # Note that `.` refers to the grouped `df`.
          {filter(ID_pos, ISRC_ID == .)} %>% 
          pull(Position)
      }) %>% 
      # Create a label for the legend (and for plotting)
      mutate(Label = {
        # Note that `.$Ref_Position` refers to the columns of all groups, not just the group at hand.
        max_pos_in_range <- max(unique(.$Ref_Position))
        # Obtain the ISRC_ID for each group individually. (This is not possible outside of this scope!)
        grouping_ISRC <- unique(ISRC_ID)
        # Take the `Ref_positiona nd convert it to a string with a with of 2.`
        ref_pos_string <- unique(Ref_Position)%>% 
          
          str_pad(floor(log10(max_pos_in_range)) + 1, "left", "0")
        # Get the country code out of the ISRC_ID.
        # Note: If the ISRC_ID starts with "TID:" it refers the the internal Spotify ID.
        # The internal Spotify ID does not provide a country code and indicate a deleted track.
        country_code <- ifelse(str_starts(grouping_ISRC, "TID:"),
                               "??",
                               str_sub(grouping_ISRC, 1, 2) %>% 
                                 # The ISRC country code may deviate from the ISO 3166-1 alpha 2 code.
                                 # Convert the ISRC country code appropriately
                                 # See: https://isrc.ifpi.org/downloads/ISRC_Bulletin-2015-01.pdf
                                 # Use {...} notation to prevent the complete output to be piped as the first argument by default.
                                 {
                                   case_when(. %in% c("BR", "BX", "BC") ~ "BR",
                                             . %in% c("FR", "FX") ~ "FR",
                                             . %in% c("GB", "UK") ~ "GB",
                                             . %in% c("US", "QM", "QZ") ~ "US",
                                             TRUE ~ .)
                                   })
        # Use `as.character()` to suppress warnigns
        # (https://stackoverflow.com/questions/52403164/r-dplyr-rowwise-mutate-glue-how-to-get-refer-row-content)
        as.character(glue("Pos {ref_pos_string}: {Artist} ({country_code})"))
        }) %>% 
      ungroup() %>% 
      # Use braces {...} to create a block to be able to:
      # 1. declare `hover_text`
      # 2. pipe to `ggplot(...)`
      {
        hover_text <- glue("<b>{.$Date}</b>\n",
                           "Artist: {.$Artist}\n",
                           "Track: {.$Track}\n",
                           "Ref. Position: {.$Ref_Position}\n",
                           "Cur. Position: {.$Position}") %>%
          # Replace any quotation mark in `glue(...)` by an empty string.
          str_replace("\"", "")
        
      # print(. %>% select(Artist) %>% unique() %>% pull())
      # Use aes_string() in order to be able to pass aesthetics as strings,
      # especially `input$pos_vs_streams`.
      ggplot(., aes_string(x = "Date",
                        y = input$pos_vs_streams,
                        color = "Label",
                        text = "hover_text")) +
        # IMPORTANT: Need to specify the grouping aesthetic, 
        # since the group aesthetic is a combination of all discrete mappings by default.
        geom_line(aes_string(group = "Label")) + 
        geom_point(size = 0.5) + 
        # geom_point(aes()) +
        # The x-intercept needs to be numeric for `ggplotly()` to work.
        # (https://stackoverflow.com/questions/52735018/ggplotly-does-not-display-geom-vline-geom-hline-when-data-is-posixct)
        geom_vline(xintercept = as.numeric(input$ref_date), colour = "gray50", size = 0.2, linetype = "dashed") + 
        xlim(min(input$obs_range), max(input$obs_range)) + 
        theme(legend.title=element_blank())
      }
    
    if (input$pos_vs_streams == "Position") {
      p <- p + scale_y_reverse()
    } else {
      p <- p + scale_y_log10()
    }

    # Generate a plotly as required for the `expr` argument of `renderPlotly()`.
    # Use `tooltip="text"` to only use what is written in the `text` easthetic as hover text.
    p <- ggplotly(p, tooltip="text",
                  width = (0.95*as.numeric(input$dimension[1])),
                  height = (0.85*as.numeric(input$dimension[2]))) %>% 
      layout(legend=list(title=list(text='<b> Legend </b>')))
  })
  
  
  ### FEATURE PLOT
  output$features <- renderPlotly({
    # Select solely the tracks tracks at `input$ref_date`.
    p <- feature_df %>%
      filter(Date == input$ref_date & Position >= prev_pos_range$min & Position <= prev_pos_range$max) %>% 
      group_by(ISRC_ID) %>% 
      # Create a label for the legend (and for plotting)
      mutate(Label = {
        # Note that `.$Position` refers to the columns of all groups, not just the group at hand.
        max_pos_in_range <- max(unique(.$Position))
        # Obtain the ISRC_ID for each group individually. (This is not possible outside of this scope!)
        grouping_ISRC <- unique(ISRC_ID)
        # Take the `Ref_positiona nd convert it to a string with a with of 2.`
        pos_string <- unique(Position) %>% 
          str_pad(floor(log10(max_pos_in_range)), "left", "0")
        # Get the country code out of the ISRC_ID.
        # Note: If the ISRC_ID starts with "TID:" it refers the the internal Spotify ID.
        # The internal Spotify ID does not provide a country code and indicate a deleted track.
        country_code <- ifelse(str_starts(grouping_ISRC, "TID:"),
                               "??",
                               str_sub(grouping_ISRC, 1, 2) %>% 
                                 # The ISRC country code may deviate from the ISO 3166-1 alpha 2 code.
                                 # Convert the ISRC country code appropriately
                                 # See: https://isrc.ifpi.org/downloads/ISRC_Bulletin-2015-01.pdf
                                 # Use {...} notation to prevent the complete output to be piped as the first argument by default.
                                 {
                                   case_when(. %in% c("BR", "BX", "BC") ~ "BR",
                                             . %in% c("FR", "FX") ~ "FR",
                                             . %in% c("GB", "UK") ~ "GB",
                                             . %in% c("US", "QM", "QZ") ~ "US",
                                             TRUE ~ .)
                                 })
        # Use `as.character()` to suppress warnigns
        # (https://stackoverflow.com/questions/52403164/r-dplyr-rowwise-mutate-glue-how-to-get-refer-row-content)
        as.character(glue("Pos {pos_string}: {Artist} ({country_code})"))
      }) %>% 
      ungroup() %>% 
      # Use braces {...} to create a block to be able to:
      # 1. declare `hover_text`
      # 2. pipe to `ggplot(...)`
      {
        hover_text <- glue("<b>{.$Date}</b>\n",
                           "Artist: {.$Artist}\n",
                           "Track: {.$Track}\n",
                           "Position: {.$Position}\n",
                           "{.$Features}: {.$Values}") %>%
          # Replace any quotation mark in `glue(...)` by an empty string.
          str_replace("\"", "")
        
        # Assign the background reference data for the box and wiskers plot.
        background_df <- switch(input$background_ref,
                                 "Week" = feature_df %>% filter(week(Date) == week(input$ref_date)),
                                 "Month" = feature_df %>% filter(month(Date) == month(input$ref_date)),
                                 "Year" = feature_df %>% filter(year(Date) == year(input$ref_date)),
                                 "All" = feature_df)
        
        ggplot(mapping = aes(text = hover_text)) + 
          # The boxplot should be completely isolated from the rest, thus use `inherit.aes = FALSE`
          geom_boxplot(data = background_df , mapping = aes(x = 1, y = Values), inherit.aes = FALSE) +
          geom_point(data = ., mapping = aes(x = 1,
                                             y = Values,
                                             color = Label)) + 
          facet_wrap(vars(Features), ncol = 4, scales = "free_y") + 
          theme(axis.title.x=element_blank(),
                axis.text.x=element_blank(),
                axis.ticks.x=element_blank(),
                axis.title.y=element_blank(),
                legend.title=element_blank())
      }
    
    p <- ggplotly(p, tooltip="text",
                  width = (0.95*as.numeric(input$dimension[1])),
                  height = (0.85*as.numeric(input$dimension[2]))) %>% 
      layout(legend=list(title=list(text='<b> Legend </b>')))
  })
}

shinyApp(ui = ui, server = server)